package sirnple.shadowsocks.remote

import sirnple.shadowsocks.core.{Cryptor, buildDownwardSsPacket, tryUnBuildSsPacket, ATYP_IPv4, ATYP_IPv6, ATYP_DOMAINNAME, RELAY_BLOCK_SIZE, IV_LEN, buildFollowSsPacketWhichNoIv, DstAddr}
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
                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                    let readCount = localSock.read(buf)
                    if (readCount == 0) {
                        status = Destory
                        break
                    }
                    log.debug("Receive first packet ${readCount} bytes from local server")
                    if (let Some((iv, atyp, dstAddr, dstPort, data)) <- tryUnBuildUpwardSsPacket(cryptor, buf[0..readCount])) {
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

                        let upwardRelay = spawn {
                            while (true) {
                                let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                let readCount = localSock.read(buf)
                                if (readCount == 0) {
                                    break
                                }
                                log.debug("Receive ${readCount} bytes from local server")
                                match (dstSock) {
                                    case Some(dstSock0) => 
                                        let decrypted = cryptor.decryptWithGivenIv(iv: iv, data: buf[0..readCount])
                                        dstSock0.write(decrypted)
                                        log.debug("Send ${decrypted.size} bytes to dst")
                                    case None => 
                                        log.warn("Never should reach here")
                                        status = Destory
                                        break
                                }
                            }
                        }
                        let downwardRelay = spawn {
                            while (true) {
                                let buf = Array<Byte>(RELAY_BLOCK_SIZE - IV_LEN - 1, item: 0)
                                try {
                                    let readCount = dstSock.getOrThrow().read(buf)
                                    if (readCount != 0) {
                                        log.debug("Receive ${readCount} bytes from dst")
                                        let packet = buildDownwardSsPacket(cryptor, iv: iv, rawData: buf[0..readCount])
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
                    } else {
                        log.warn("Can't parse packet")
                        status = Disconnected
                    }
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

    private func tryUnBuildUpwardSsPacket(cryptor: Cryptor, ssPacket: Array<Byte>): ?(iv: Array<Byte>, atyp: Byte, dstAddr: Array<Byte>, dstPort: Array<Byte>, decryptedData: Array<Byte>) {
        match (tryUnBuildSsPacket(cryptor, ssPacket)) {
            case None => return None
            case Some((iv, data)) =>
                let atyp = data[0]
                if (atyp == ATYP_IPv4) {
                    log.debug("Unbuild SS packet, dst address is ${SocketAddress(IPv4, data[1..5], UInt16(data[5])<<8 | UInt16(data[6]))}")
                    return (iv, atyp, data[1..5], data[5..7], data[7..data.size])
                }
                if (atyp == ATYP_IPv6) {
                    log.debug("Unbuild SS packet, dst address is ${SocketAddress(IPv6, data[1..17], UInt16(data[17])<<8 | UInt16(data[18]))}")
                    return (iv, atyp, data[1..17], data[17..19], data[19..data.size])
                }
                if (atyp == ATYP_DOMAINNAME) {
                    // data格式: atyp + domainNameLen + domainName + port + payload
                    let domainNameLen = data[1]
                    let domainName = data[2..Int64(domainNameLen) + 2]
                    let port = data[Int64(domainNameLen) + 2..Int64(domainNameLen) + 4]
                    let payload = data[Int64(domainNameLen) + 4..data.size]
                    log.debug("Unbuild SS packet, dst address is ${String.fromUtf8(domainName)}:${UInt16(port[0])<<8 | UInt16(port[1])}")
                    return (iv, atyp, domainName, port, payload)
                }
                log.debug("ATYP must be ${ATYP_IPv4}, ${ATYP_DOMAINNAME}, or ${ATYP_IPv6}, but is ${atyp}")
                return None
        }
    }
}