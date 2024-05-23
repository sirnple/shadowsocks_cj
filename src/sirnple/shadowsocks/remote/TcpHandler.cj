package sirnple.shadowsocks.remote

import sirnple.shadowsocks.core.{Cryptor, buildDownwardSsPacket, tryUnBuildSsPacket, ATYP_IPv4, ATYP_IPv6, ATYP_DOMAINNAME, RELAY_BLOCK_SIZE, IV_LEN}
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
                        var iv: Option<Array<Byte>> = None
                        while (true) {
                            let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                            let readCount = localSock.read(buf)
                            if (readCount == 0) {
                                break
                            }
                            log.debug("Receive ${readCount} bytes from local server")
                            match (dstSock) {
                                case Some(dstSock0) where iv.isSome() => 
                                    let decrypted = cryptor.decrypt(iv.getOrThrow(), buf[0..readCount])
                                    dstSock0.write(decrypted)
                                    log.debug("Send ${decrypted.size} bytes to dst")
                                case _ => 
                                    let packet = tryUnBuildUpwardSsPacket(cryptor, buf[0..readCount])
                                    match (packet) {
                                        case Some((iv0, atyp, dstAddr, dstPort, data)) => 
                                            iv = Some(iv0)
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
                                                case _ => throw Exception("Unsupported atyp ${atyp}, please check tryUnBuildUpwardSsPacket implementation")
                                            }
                                            dstSock.getOrThrow().connect()
                                            dstSock.getOrThrow().write(data)
                                            log.debug("Send ${data.size} bytes to dst")
                                        case None => 
                                            log.warn("Can't parse packet")
                                            status = Status.Disconnected
                                            break
                                    }
                            }
                        }
                    }
                    let downwardRelay = spawn {
                        while (true) {
                            if (dstSock.isNone()) {
                                continue
                            }
                            let buf = Array<Byte>(RELAY_BLOCK_SIZE - IV_LEN - 1, item: 0)
                            try {
                                let readCount = dstSock.getOrThrow().read(buf)
                                if (readCount != 0) {
                                    log.debug("Receive ${readCount} bytes from dst")
                                    let packet = buildDownwardSsPacket(cryptor, buf[0..readCount])
                                    assert(packet.size <= RELAY_BLOCK_SIZE, message: "Packet size is too large, max size is ${RELAY_BLOCK_SIZE}, but actual size is ${packet.size}")
                                    localSock.write(packet)
                                    log.debug("Send ${packet.size} bytes to local server")
                                } else {
                                    break
                                }
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

    /** 
    * 解包 SS 包， 这里是上行的TCP包，包含有dst.addr和dst.port
    * @param cryptor 解密器
    * @param ssPacket SS 包，iv.len + iv + encryptedData
    * @return Some((iv, atyp, dst.addr, dst.port, data)) or None
    */
    private func tryUnBuildUpwardSsPacket(cryptor: Cryptor, ssPacket: Array<Byte>): ?(Array<Byte>, Byte, Array<Byte>, Array<Byte>, Array<Byte>) {
        match (tryUnBuildSsPacket(cryptor, ssPacket)) {
            case None => return None
            case Some((iv, data)) =>
                let atyp = data[0]
                if (atyp == ATYP_IPv4) {
                    return (iv, atyp, data[1..5], data[5..7], data[7..data.size])
                }
                if (atyp == ATYP_IPv6) {
                    return (iv, atyp, data[1..17], data[17..19], data[19..data.size])
                }
                if (atyp == ATYP_DOMAINNAME) {
                    return (iv, atyp, data[1..2], data[2..4], data[4..data.size])
                }
                log.debug("ATYP must be ${ATYP_IPv4}, ${ATYP_DOMAINNAME}, or ${ATYP_IPv6}, but is ${atyp}")
                return None
        }
    }
}