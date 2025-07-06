package shadowsocks_cj.local

import shadowsocks_cj.config.{ShadowsocksConfig, LOG_CONFIG}
import shadowsocks_cj.core.*
import shadowsocks_cj.core.crypto.{ShadowsocksCryptor, PasswordCryptor}
import shadowsocks_cj.util.assert
import std.env.getStdOut
import std.net.*
import stdx.logger.SimpleLogger
import std.reflect.*
import std.console.Console

class TcpHandler {
    private static let log = SimpleLogger(getStdOut()).withAttrs([("name", "local.TcpHandler")])
    private var myRemoteSock: Option<TcpSocket> = None
    private var status: Status = Status.Init
    private var myDstAddr: Option<DstAddr> = None
    private let ssCryptor: ShadowsocksCryptor

    public TcpHandler(let config: ShadowsocksConfig, let clientSock: TcpSocket) {
        clientSock.readTimeout = Duration.second * 1
        ssCryptor = PasswordCryptor(config.password, config.method)
        log.level = LOG_CONFIG.logLevel
    }

    public func handle() {
        spawn {
            handle0()
        }
    }

    private func handle0() {
        while (true) {
            match (status) {
                case Status.Init =>
                    // 确保socket可用
                    log.debug("Status Init")
                    assert(!clientSock.isClosed(), message: "Connection with client is broken, socket is closed")
                    status = Status.Auth
                case Auth =>
                    log.debug("Status Auth")
                    let buf = Array<Byte>(AUTH_REQUEST_MAX_LEN, repeat: 0)
                    let readCount = clientSock.read(buf)
                    match (tryProcessSocks5AuthRequest(buf[0..readCount])) {
                        case Some(authResponse) =>
                            clientSock.write(authResponse)
                            log.debug("Auth success, auth response: ${authResponse}")
                            status = Status.Negotiating
                        case None =>
                            log.warn("Auth failed: read ${buf[0..readCount]} is not a valid auth frame")
                            status = Status.Closing
                    }
                case Negotiating =>
                    log.debug("Status Negotiating")
                    let buf = Array<Byte>(ADDR_NEGOTIATE_MAX_LEN, repeat: 0)
                    let readCount = clientSock.read(buf)
                    match (tryProcessNegotiationRequest(buf[0..readCount])) {
                        case Some((ver, cmd, rsv, atyp, addr, port)) =>
                            myDstAddr = Some(DstAddr(atyp, addr, port))
                            let newRemoteSock = TcpSocket(IPSocketAddress(config.server, config.serverPort))
                            newRemoteSock.readTimeout = Duration.second * 1
                            newRemoteSock.connect()
                            myRemoteSock = Some(newRemoteSock)
                            let bindAddr = (newRemoteSock.localAddress as IPSocketAddress)
                                .getOrThrow({=> Exception("Should never happen")})
                                .address
                            let bindPort = (newRemoteSock.localAddress as IPSocketAddress)
                                .getOrThrow({=> Exception("Should never happen")})
                                .port
                            let bindAtyp = match {
                                case newRemoteSock.localAddress.family == AddressFamily.INET => 
                                    assert(bindAddr.getAddressBytes().size == 4, message: "")
                                    ATYP_IPv4
                                case newRemoteSock.localAddress.family == AddressFamily.INET6 => 
                                    assert(bindAddr.getAddressBytes().size == 16, message: "")
                                    ATYP_IPv6
                                case _ => throw Exception("Should never happen")
                            }
                            clientSock.write(buildSuccessNegotiationResponse(bindAtyp, bindAddr.getAddressBytes(),[UInt8(bindPort >> 8), UInt8(bindPort & 0xff)]))
                            log.debug(
                                "Negotiation success, sockBindToRemoteServer: ${bindAtyp} ${bindAddr} ${bindPort}, remoteServer: ${config.server} ${config.serverPort}"
                            )
                            status = Status.Established
                        case None =>
                            log.warn("Negotiating failed: read ${buf[0..readCount]} is not a valid negotiation frame")
                            status = Status.Closing
                    }
                case Established =>
                    log.debug("Status Established")
                    // some operations could be done here
                    status = Transerring
                case Transerring =>
                    log.debug("Status Transerring")
                    let upwardRelay = spawn {
                        var first = true
                        while (true) {
                            match ((myDstAddr, myRemoteSock)) {
                                case (Some(dstAddr), Some(remoteSock)) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, repeat: 0)
                                    try {
                                        let readCount = clientSock.read(buf)
                                        if (readCount == 0) {
                                            log.debug("Client socket is closed", ("line", @sourceLine()))
                                            break
                                        }
                                        log.debug(
                                            "Receive packet from client, ${readCount} bytes",
                                            ("line", @sourceLine())
                                        )
                                        let packet = match (first) {
                                            case true => 
                                                let a = ssCryptor.encrypt(packSsLocalSendFirstSsPacket(dstAddr, buf[0..readCount]))
                                                first = false
                                                a
                                            case false => ssCryptor.encrypt(buf[0..readCount])
                                        }
                                        remoteSock.write(packet)
                                        log.debug(
                                            "Send packet to ss-remote, ${packet.size} bytes",
                                            ("line", @sourceLine())
                                        )
                                    } catch (e: SocketException | SocketTimeoutException) {
                                        log.warn("upward relay failed, ${e.message}", ("line", @sourceLine()))
                                        break
                                    }
                                case _ =>
                                    log.warn("Invalid status, remoteSock should create in AddressNegotiationResponse status", ("line", @sourceLine()))
                                    break
                            }
                        }
                    }

                    let downwardRelay = spawn {
                        while (true) {
                            match (myRemoteSock) {
                                case Some(remoteSock) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, repeat: 0)
                                    try {
                                        let readCount = remoteSock.read(buf)
                                        if (readCount == 0) {
                                            log.debug("ss-remote is closed", ("line", @sourceLine()))
                                            break
                                        }
                                        log.debug(
                                            "Receive packet from ss-remote, ${readCount} bytes",
                                            ("line", @sourceLine())
                                        )
                                        let payload = ssCryptor.decrypt(buf[0..readCount])
                                        clientSock.write(payload)
                                        log.debug(
                                            "Send packet to client, ${payload.size} bytes",
                                            ("line", @sourceLine())
                                        )
                                    } catch (e: SocketException | SocketTimeoutException) {
                                        log.warn("downward relay failed, ${e.message}", ("line", @sourceLine()))
                                        break
                                    }
                                case _ =>
                                    log.warn("Invalid status, remoteSock should create in Connected status", ("line", @sourceLine()))
                                    break
                            }
                        }
                    }
                    upwardRelay.get()
                    downwardRelay.get()
                    status = Closing
                case Closing =>
                    log.debug("Status Closing")
                    match (myRemoteSock) {
                        case Some(s) =>
                            if (!s.isClosed()) {
                                s.close()
                            }
                        case None => ()
                    }
                    if (!clientSock.isClosed()) {
                        clientSock.close()
                    }
                    log.debug("Connection closed")
                    break
            }
        }
    }
}
