package shadowsocks_cj.remote

import shadowsocks_cj.core.{
    tryUnpackSsRemoteFirstReceivedPacket,
    ATYP_IPv4,
    ATYP_IPv6,
    ATYP_DOMAINNAME,
    RELAY_BLOCK_SIZE,
    IV_LEN,
    DstAddr,
    ArrayExt,
    SS_REMOTE_FIRST_SEND_PAYLOAD_MAX_SIZE
}
import shadowsocks_cj.core.crypto.{ShadowsocksCryptor, PasswordCryptor}
import shadowsocks_cj.util.assert
import shadowsocks_cj.config.{ShadowsocksConfig, LOG_CONFIG}
import stdx.logger.SimpleLogger
import std.reflect.TypeInfo
import std.console.Console
import std.net.{TcpSocket, IPSocketAddress, IPAddress, SocketException}
import std.env.getStdOut

class TcpHandler {
    private static let log = SimpleLogger(getStdOut())
    private var status = Status.Init
    private var myDstSock: ?TcpSocket = None
    private let ssCryptor: ShadowsocksCryptor

    static init() {
        log.level = LOG_CONFIG.logLevel
    }

    public TcpHandler(let config: ShadowsocksConfig, let localSock: TcpSocket) {
        ssCryptor = PasswordCryptor(config.password, config.method)
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
                    log.debug("Status Init")
                    assert(!localSock.isClosed(), message: "Connection with client is broken, socket is closed")
                    status = Status.Connected
                case Status.Connected =>
                    log.debug("Status Connected")
                    let upwardRelay = spawn {
                        while (true) {
                            match (myDstSock) {
                                case None =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, repeat: 0)
                                    let readCount = localSock.read(buf)
                                    if (readCount == 0) {
                                        break
                                    }

                                    log.debug("Receive encrypted packet from ss-local, ${readCount} bytes")
                                    let decrypted = ssCryptor.decrypt(buf[0..readCount])
                                    
                                    if (let Some((atyp, dstAddr, dstPort, payload)) <- tryUnpackSsRemoteFirstReceivedPacket(decrypted)) {
                                        match {
                                            case atyp == ATYP_IPv4 =>
                                                myDstSock = TcpSocket(IPSocketAddress(dstAddr, UInt16(dstPort[0])<<8 | UInt16(dstPort[1])))
                                            case atyp == ATYP_IPv6 =>
                                                myDstSock = TcpSocket(IPSocketAddress(dstAddr, UInt16(dstPort[0])<<8 | UInt16(dstPort[1])))
                                            case atyp == ATYP_DOMAINNAME =>
                                                let resolvedAddr = IPAddress.resolve(String.fromUtf8(dstAddr))
                                                if (resolvedAddr.isEmpty()) {
                                                    log.warn("Can't resolve domain name ${String.fromUtf8(dstAddr)}:${UInt16(dstPort[0])<<8 | UInt16(dstPort[1])}")
                                                    break
                                                }
                                                let tmpSock = TcpSocket(IPSocketAddress(resolvedAddr[0], UInt16(dstPort[0])<<8 | UInt16(dstPort[1])))
                                                myDstSock = Some(tmpSock)
                                                tmpSock.connect()
                                                tmpSock.write(payload)
                                                log.debug("Send packet to dst server, ${payload.size} bytes")
                                            case _ =>
                                                log.warn("Can't parse packet")
                                                break
                                        }
                                    } else {
                                        log.warn("Invalid decrypted packet, size: ${decrypted.size}, content: ${decrypted}")
                                        break
                                    }
                                case Some(dstSock) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, repeat: 0)
                                    try {
                                        let readCount = localSock.read(buf)
                                        if (readCount == 0) {
                                            break
                                        }
                                        log.debug("Receive packet from ss-local, ${readCount} bytes")
                                        let payload = ssCryptor.decrypt(buf[0..readCount])
                                        dstSock.write(payload)
                                        log.debug("Send packet to dst server, ${payload.size} bytes")
                                    } catch (e: SocketException) {
                                        log.warn("upward relay failed, ${e.message}")
                                        break
                                    }
                            }
                        }
                    }
                    let downwardRelay = spawn {
                        while (true) {
                            match (myDstSock) {
                                case None =>
                                    // dstSock is not ready, need wait for dstSock init in upwardRelay
                                    continue
                                case Some(dstSock) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, repeat: 0)
                                    try {
                                        let readCount = dstSock.read(buf)
                                        if (readCount == 0) {
                                            break
                                        }
                                        log.debug("Receive packet from dst server, ${readCount} bytes")
                                        let encrypted = ssCryptor.encrypt(buf[0..readCount])
                                        localSock.write(encrypted)
                                        log.debug("Send packet to ss-local, ${encrypted.size} bytes")
                                    } catch (e: SocketException) {
                                        if (e.message.contains("Socket is not connected")) {
                                            continue
                                        } else {
                                            log.warn("Read from remote server failed, ${e.message}")
                                            break
                                        }
                                    }
                            }
                        }
                    }
                    upwardRelay.get()
                    downwardRelay.get()
                    status = Status.Disconnected
                case Status.Disconnected =>
                    log.debug("Status Disconnected")
                    match (myDstSock) {
                        case Some(s) =>
                            if (!s.isClosed()) {
                                s.close()
                            }
                        case None => ()
                    }
                    if (!localSock.isClosed()) {
                        localSock.close()
                    }
                    status = Status.Destory
                case Destory => 
                    log.debug("Status Destory")
                    break
            }

        }
    }
}
