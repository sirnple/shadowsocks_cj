package shadowsocks_cj.sirnple.shadowsocks.local

import shadowsocks_cj.sirnple.shadowsocks.config.{ShadowsocksConfig, LOG_CONFIG}
import shadowsocks_cj.sirnple.shadowsocks.core.*
import shadowsocks_cj.sirnple.shadowsocks.util.assert

import std.net.*
import logger.SimpleLogger
import std.reflect.*
import std.console.Console

class TcpHandler {
    private static let log = SimpleLogger(Console.stdOut)
    private var myRemoteSock: Option<TcpSocket> = None
    private var status: Status = Status.Init
    private var myDstAddr: Option<DstAddr> = None
    private let ssCryptor: ShadowsocksCryptor

    public TcpHandler(let config: ShadowsocksConfig, let clientSock: TcpSocket) {
        ssCryptor = PasswordCryptor(config.password, config.method)
        log.level = LOG_CONFIG.logLevel
    }

    public func handle() {
        spawn {
            handle0()
        }
    }

    private func handle0() {
        while(true) {
            match(status) {
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
                            status = Status.AddressNegotiationRequest
                        case None => 
                            log.warn("Auth: read ${buf[0..readCount]} is not a valid auth frame, please try again")
                            continue
                    }
                case AddressNegotiationRequest =>
                    log.debug("Status AddressNegotiationRequest")
                    let buf = Array<Byte>(ADDR_NEGOTIATE_MAX_LEN, repeat: 0)
                    let readCount = clientSock.read(buf)
                    match (tryProcessNegotiationRequest(buf[0..readCount])) {
                        case Some((ver, cmd, rsv, atyp, addr, port)) =>
                            myDstAddr = Some(DstAddr(atyp, addr, port))
                            status = Status.AddressNegotiationResponse
                        case None => 
                            log.warn("Invalid status, bad address negotiation request")
                            status = Disconnected
                    }
                case AddressNegotiationResponse =>
                    log.debug("Status AddressNegotiationResponse")
                    match((myDstAddr, myRemoteSock)) {
                        case (None, _) =>
                            log.warn("Invalid status, address negotiation not completed")
                            status = Disconnected
                        case (Some(addr), _) =>
                            let newRemoteSock = TcpSocket(IPSocketAddress(config.server, config.serverPort))
                            newRemoteSock.connect()
                            myRemoteSock = Some(newRemoteSock)
                            let bindAddr = newRemoteSock.localAddress.getAddressBytes()
                            let bindPort = (newRemoteSock.localAddress as IPSocketAddress).getOrThrow({ => Exception("Should never happen")}).port
                            let bindAtyp = match {
                                case newRemoteSock.localAddress.family == AddressFamily.INET => ATYP_IPv4
                                case newRemoteSock.localAddress.family == AddressFamily.INET6 => ATYP_IPv6
                                case _ => throw Exception("Should never happen")
                            }
                            clientSock.write(buildSuccessNegotiationResponse(bindAtyp, bindAddr, [UInt8(bindPort>>8), UInt8(bindPort&0xff)]))
                            status = Connected
                    }
                case Connected =>
                    log.debug("Status Connected")
                    let upwardRelay = spawn {
                        var isFirst = true
                        while (true) {
                            match ((myDstAddr, myRemoteSock, isFirst)) {
                                case (Some(dstAddr), Some(remoteSock), true) =>
                                    let buf = Array<Byte>(SS_LOCAL_FIRST_SEND_PAYLOAD_MAX_SIZE, repeat: 0)
                                    let readCount = clientSock.read(buf)
                                    if (readCount == 0) {
                                        log.debug("Client socket is closed and nothing is relayed")
                                        break
                                    }
                                    log.debug("Receive first packet from client, ${readCount} bytes\nbefore encrypted: ${buf[0..readCount]}")
                                    let packet = ssCryptor.encryptFirst(packSsLocalSendFirstSsPacket(dstAddr, buf[0..readCount]))
                                    remoteSock.write(packet)
                                    log.debug("Send first packet to ss-remote, ${packet.size} bytes\nafter encrypted: ${packet[0..packet.size]}")
                                    isFirst = false
                                case (Some(dstAddr), Some(remoteSock), false) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, repeat: 0)
                                    let readCount = clientSock.read(buf)
                                    if (readCount != 0) {
                                        log.debug("Receive follow packet from client, ${readCount} bytes\nbefore encrypted: ${buf[0..readCount]}")
                                        let packet = ssCryptor.encryptFollow(buf[0..readCount])
                                        remoteSock.write(packet)
                                        log.debug("Send follow packet to ss-remote, ${packet.size} bytes\nafter encrypted: ${packet[0..packet.size]}")
                                    } else {
                                        log.debug("Client socket is closed and nothing is relayed")
                                        break
                                    }
                                case (_, _, _) =>
                                    log.warn("Invalid status, remoteSock should create in AddressNegotiationResponse status")
                                    break
                            }
                        }
                    }

                    let downwardRelay = spawn {
                        var isFirst = true
                        while (true) {
                            match ((isFirst, myRemoteSock)) {
                                case (true, Some(remoteSock)) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, repeat: 0)
                                    let readCount = remoteSock.read(buf)
                                    if (readCount == 0) {
                                        log.debug("ss-remote is closed")
                                        break
                                    }
                                    log.debug("Receive first packet from ss-remote, ${readCount} bytes\nbefore decrypted: ${buf[0..readCount]}")
                                    let payload = ssCryptor.decryptFirst(buf[0..readCount])
                                    clientSock.write(payload)
                                    log.debug("Send first packet to client, ${payload.size} bytes\nafter decrypted: ${payload[0..payload.size]}")
                                    isFirst = false
                                case (false, Some(remoteSock)) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, repeat: 0)
                                    try {
                                        let readCount = remoteSock.read(buf)
                                        if (readCount == 0) {
                                            log.debug("ss-remote is closed")
                                            break
                                        }
                                        log.debug("Receive follow packet from ss-remote, ${readCount} bytes\nbefore decrypted: ${buf[0..readCount]}")
                                        let payload = ssCryptor.decryptFollow(buf[0..readCount])
                                        clientSock.write(payload)
                                        log.debug("Send follow packet to client, ${payload.size} bytes\nafter decrypted: ${payload[0..payload.size]}")
                                    } catch (e: SocketException) {
                                        if (e.message.contains("Socket is not connected") || e.message.contains("Socket is already closed")) {
                                            continue
                                        } else {
                                            log.warn("Read from ss-remote failed, ${e.message}")
                                        }
                                    }
                                case (_, _) =>
                                    log.warn("Invalid status, remoteSock should create in Connected status")
                                    break
                            }
                        }
                    }
                    upwardRelay.get()
                    downwardRelay.get()
                    status = Disconnected
                case Disconnected =>
                    log.debug("Status Disconnected")
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
                    status = Status.Destory
                case _ =>
                    log.debug("Status Destory")
                    break
            }
        }
    }
}