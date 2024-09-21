package shadowsocks_cj.sirnple.shadowsocks.remote

import shadowsocks_cj.sirnple.shadowsocks.core.{
    tryUnpackSsRemoteFirstReceivedPacket,
    PasswordCryptor,
    ShadowsocksCryptor,
    ATYP_IPv4,
    ATYP_IPv6,
    ATYP_DOMAINNAME,
    RELAY_BLOCK_SIZE,
    IV_LEN,
    DstAddr,
    ArrayExt,
    SS_REMOTE_FIRST_SEND_PAYLOAD_MAX_SIZE
}
import shadowsocks_cj.sirnple.shadowsocks.util.assert
import shadowsocks_cj.sirnple.shadowsocks.config.{ShadowsocksConfig, LOG_CONFIG}
import std.log.SimpleLogger
import std.reflect.TypeInfo
import std.console.Console
import std.net.{TcpSocket, IPSocketAddress, IPAddress, SocketException}

class TcpHandler {
    private let log = SimpleLogger(TypeInfo.of<TcpHandler>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private var status = Status.Init
    private var myDstSock: ?TcpSocket = None
    private let ssCryptor: ShadowsocksCryptor
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
                        var isFirst = true
                        while (true) {
                            match ((myDstSock, isFirst)) {
                                case (None, true) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    let readCount = localSock.read(buf)
                                    if (readCount == 0) {
                                        break
                                    }

                                    log.debug("Receive first encrypted packet from ss-local, ${readCount} bytes\n${buf[0..readCount]}")
                                    let decrypted = ssCryptor.decryptFirst(buf[0..readCount])
                                    
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
                                                let tmpSock = TcpSocket(IPSocketAddress(resolvedAddr[0] /* 取解析出来的第一个IP */, UInt16(dstPort[0])<<8 | UInt16(dstPort[1])))
                                                myDstSock = Some(tmpSock)
                                                tmpSock.connect()
                                                tmpSock.write(payload)
                                                isFirst = false
                                                log.debug("Send first packet to dst server, ${payload.size} bytes\nafter decrypted: ${payload}")
                                            case _ =>
                                                log.warn("Can't parse packet")
                                                break
                                        }
                                    } else {
                                        log.warn("Invalid first decrypted packet, size: ${decrypted.size}, content: ${decrypted}")
                                        break
                                    }
                                case (Some(dstSock), false) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    let readCount = localSock.read(buf)
                                    if (readCount == 0) {
                                        break
                                    }
                                    log.debug("Receive follow packet from ss-local, ${readCount} bytes\nbefore decrypted: ${buf[0..readCount]}")
                                    let payload = ssCryptor.decryptFollow(buf[0..readCount])
                                    dstSock.write(payload)
                                    log.debug("Send follow packet to dst server, ${payload.size} bytes\nafter decrypted: ${payload}")
                                case _ =>
                                    log.warn("Invalid status, myDstSock must be Some")
                                    break
                            }
                        }
                    }
                    let downwardRelay = spawn {
                        var isFirst = true
                        while (true) {
                            match ((isFirst, myDstSock)) {
                                case (_, None) =>
                                    // dstSock is not ready, need wait for dstSock init in upwardRelay
                                    continue
                                case (true, Some(dstSock)) =>
                                    // send first packet
                                    let buf = Array<Byte>(SS_REMOTE_FIRST_SEND_PAYLOAD_MAX_SIZE, item: 0)
                                    try {
                                        let readCount = dstSock.read(buf)
                                        if (readCount == 0) {
                                            break
                                        }
                                        log.debug("Receive first packet from dst server, ${readCount} bytes\nbefore encrypted: ${buf[0..readCount]}")
                                        let encrypted = ssCryptor.encryptFirst(buf[0..readCount])
                                        localSock.write(encrypted)
                                        log.debug("Send first packet to ss-local, ${encrypted.size} bytes\nafter encrypted: ${encrypted}")
                                        isFirst = false
                                    } catch (e: SocketException) {
                                        if (e.message.contains("Socket is not connected")) {
                                            continue
                                        } else {
                                            log.warn("Read from remote server failed, ${e.message}")
                                            break
                                        }
                                    }
                                case (false, Some(dstSock)) =>
                                    // send follow packet
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    let readCount = dstSock.read(buf)
                                    if (readCount == 0) {
                                        break
                                    }
                                    log.debug("Receive follow packet from dst server, ${readCount} bytes\nbefore encrypted: ${buf[0..readCount]}")
                                    let encrypted = ssCryptor.encryptFollow(buf[0..readCount])
                                    localSock.write(encrypted)
                                    log.debug("Send follow packet to ss-local, ${encrypted.size} bytes\nafter encrypted: ${encrypted}")
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