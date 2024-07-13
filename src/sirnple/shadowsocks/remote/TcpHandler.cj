package sirnple.shadowsocks.remote

import sirnple.shadowsocks.core.{packSsRemoteFirstSendPacket, packFollowSsPacket, tryUnpackSsRemoteFirstReceivedPacket, Cryptor, ATYP_IPv4, ATYP_IPv6, ATYP_DOMAINNAME, RELAY_BLOCK_SIZE, IV_LEN, DstAddr, ArrayExt, SS_REMOTE_FIRST_SEND_PAYLOAD_MAX_SIZE}
import sirnple.shadowsocks.util.assert

class TcpHandler {
    private let log = SimpleLogger(TypeInfo.of<TcpHandler>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private var status = Status.Init
    private var dstSock: Option<TcpSocket> = None
    private var iv: Option<Array<Byte>> = None
    public TcpHandler(let config: ShadowsocksConfig, let localSock: TcpSocket, let cryptor: Cryptor) {}
    
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
                        var receivedIv = None<Array<Byte>>
                        while (true) {
                            match ((receivedIv, dstSock)) {
                                case (None, None) =>
                                    // receive first packet
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    let readCount = localSock.read(buf)
                                    if (readCount == 0) {
                                        break
                                    }

                                    log.debug("Receive first packet from ss-local, ${readCount} bytes\nbefore decrypted: ${buf[0..readCount]}")
                                    if (let Some((iv, atyp, dstAddr, dstPort, data)) <- tryUnpackSsRemoteFirstReceivedPacket(cryptor, buf[0..readCount])) {
                                        receivedIv = Some(iv)
                                        match {
                                            case atyp == ATYP_IPv4 =>
                                                dstSock = TcpSocket(SocketAddress(SocketAddressKind.IPv4, dstAddr, UInt16(dstPort[0])<<8 | UInt16(dstPort[1])))
                                            case atyp == ATYP_IPv6 =>
                                                dstSock = TcpSocket(SocketAddress(SocketAddressKind.IPv6, dstAddr, UInt16(dstPort[0])<<8 | UInt16(dstPort[1])))
                                            case atyp == ATYP_DOMAINNAME =>
                                                let resolvedAddr = SocketAddress.resolve(String.fromUtf8(dstAddr), UInt16(dstPort[0])<<8 | UInt16(dstPort[1]))
                                                match (resolvedAddr) {
                                                    case Some(a) =>
                                                        dstSock = TcpSocket(a)
                                                    case None =>
                                                        log.warn("Can't resolve domain name ${String.fromUtf8(dstAddr)}:${UInt16(dstPort[0])<<8 | UInt16(dstPort[1])}")
                                                        status = Status.Disconnected
                                                        break
                                                }
                                            case _ =>
                                                log.warn("Can't parse packet")
                                                status = Disconnected
                                                break
                                        }
                                        this.dstSock.getOrThrow().connect()
                                        this.dstSock.getOrThrow().write(data)
                                        log.debug("Send first packet to dst server, ${data.size} bytes\nafter decrypted: ${data}")
                                    } else {
                                        log.warn("Invalid first packet, size: ${readCount}, content: ${buf[0..readCount]}")
                                        break
                                    }
                                case (Some(iv), Some(dstSock)) =>
                                    // receive follow packet
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    let readCount = localSock.read(buf)
                                    if (readCount == 0) {
                                        break
                                    }
                                    log.debug("Receive follow packet from ss-local, ${readCount} bytes\nbefore decrypted: ${buf[0..readCount]}")
                                    let decrypted = cryptor.decryptWithGivenIv(iv: iv, data: buf[0..readCount])
                                    dstSock.write(decrypted)
                                    log.debug("Send follow packet to dst server, ${decrypted.size} bytes\nafter decrypted: ${decrypted}")
                                case (_, _) =>
                                    log.warn("Invalid status, iv and dstSock must be both Some")
                                    break
                            }
                        }
                    }
                    let downwardRelay = spawn {
                        var sendIv = Option<Array<Byte>>.None
                        while (true) {
                            match ((sendIv, dstSock)) {
                                case (_, None) =>
                                    // dstSock is not ready, need wait for dstSock init in upwardRelay
                                    continue
                                case (None, Some(dstSock)) =>
                                    // send first packet
                                    let buf = Array<Byte>(SS_REMOTE_FIRST_SEND_PAYLOAD_MAX_SIZE, item: 0)
                                    try {
                                        let readCount = dstSock.read(buf)
                                        if (readCount == 0) {
                                            break
                                        }
                                        log.debug("Receive first packet from dst server, ${readCount} bytes\nbefore encrypted: ${buf[0..readCount]}")
                                        let (iv, encrypted) = packSsRemoteFirstSendPacket(cryptor, buf[0..readCount])
                                        sendIv = Some(iv)
                                        localSock.write(iv + encrypted)
                                        log.debug("Send first packet to ss-local, ${iv.size + encrypted.size} bytes\nafter encrypted: ${iv + encrypted}")
                                    } catch (e: SocketException) {
                                        if (e.message.contains("Socket is not connected")) {
                                            continue
                                        } else {
                                            log.warn("Read from remote server failed, ${e.message}")
                                            break
                                        }
                                    }
                                case (Some(iv), Some(dstSock)) =>
                                    // send follow packet
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    let readCount = dstSock.read(buf)
                                    if (readCount == 0) {
                                        break
                                    }
                                    log.debug("Receive follow packet from dst server, ${readCount} bytes\nbefore encrypted: ${buf[0..readCount]}")
                                    let packet = packFollowSsPacket(cryptor, iv: iv, rawData: buf[0..readCount])
                                    localSock.write(packet)
                                    log.debug("Send follow packet to ss-local, ${packet.size} bytes\nafter encrypted: ${packet}")
                            }
                        }
                    }
                    upwardRelay.get()
                    downwardRelay.get()
                    status = Status.Disconnected
                case Status.Disconnected =>
                    log.debug("Status Disconnected")
                    match (dstSock) {
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