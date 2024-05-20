package sirnple.shadowsocks.remote

import sirnple.shadowsocks.core.{Cryptor, buildDownwardSsPacket, unBuildUpwardSsPacket, ATYP_IPv4, ATYP_IPv6, ATYP_DOMAINNAME}
import sirnple.shadowsocks.util.assert

class TcpHandler {
    private let log = SimpleLogger(TypeInfo.of<TcpHandler>().qualifiedName, LogLevel.ALL, Console.stdOut)
    private var status = Status.Init
    private var sock: Option<TcpSocket> = None
    public TcpHandler(let config: Config, let clientSock: TcpSocket, let cryptor: Cryptor) {}
    
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
                    assert(!clientSock.isClosed(), message: "Connection with client is broken, socket is closed")
                    status = Status.Connected
                case Status.Connected =>
                    log.debug("Status Connected")
                    let buf = Array<Byte>(4096, item: 0)
                    let readCount = clientSock.read(buf)
                    log.debug("Read ${buf[0..readCount]}")
                    if (readCount != 0) {
                        let packet = unBuildUpwardSsPacket(cryptor, buf[0..readCount])
                        match (packet) {
                            case Some((atyp, addr, port, data)) => 
                                match (sock) {
                                    case Some(_) => ()
                                    case None => 
                                        if (atyp == ATYP_IPv4) {
                                            sock = TcpSocket(SocketAddress(SocketAddressKind.IPv4, addr, UInt16(port[0])<<8 | UInt16(port[1])))
                                            sock.getOrThrow().connect()
                                        } else if (atyp == ATYP_IPv6) {
                                            sock = TcpSocket(SocketAddress(SocketAddressKind.IPv6, addr, UInt16(port[0])<<8 | UInt16(port[1])))
                                            sock.getOrThrow().connect()
                                        } else if (atyp == ATYP_DOMAINNAME) {
                                            log.warn("Not support domain name yet")
                                            continue
                                        }
                                }
                                sock.getOrThrow().write(data)
                            case None =>
                                log.warn("Read ${buf[0..readCount]} is not a valid upstream shadowsocks packet")
                                continue
                        }
                    } else {
                        status = Status.RelayUpwardFinished
                    }
                case Status.RelayUpwardFinished =>
                    log.debug("Status RelayUpwardFinished")
                    let buf = Array<Byte>(4096, item: 0)
                    let readCount = sock.getOrThrow().read(buf)
                    if (readCount != 0) {
                        let packet = buildDownwardSsPacket(cryptor, buf[0..readCount])
                        clientSock.write(packet)
                    } else {
                        status = Status.RelayDownwardFinished
                    }
                case Status.RelayDownwardFinished => 
                    log.debug("Status RelayDownwardFinished")
                    status = Status.Disconnected
                case Status.Disconnected =>
                    log.debug("Status Disconnected")
                    sock.getOrThrow().close()
                    clientSock.close()
                    status = Status.Destory
                case Destory => 
                    log.debug("Status Destory")
            }

        }
    }
}