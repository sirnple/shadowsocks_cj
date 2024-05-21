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
                    let upwardRelay = spawn {
                        while (true) {
                            let buf = Array<Byte>(4096, item: 0)
                            let readCount = clientSock.read(buf)
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
                                                    sock.getOrThrow().write(data)
                                                } else if (atyp == ATYP_IPv6) {
                                                    sock = TcpSocket(SocketAddress(SocketAddressKind.IPv6, addr, UInt16(port[0])<<8 | UInt16(port[1])))
                                                    sock.getOrThrow().connect()
                                                    sock.getOrThrow().write(data)
                                                } else if (atyp == ATYP_DOMAINNAME) {
                                                    log.warn("Not support domain name yet")
                                                    status = Status.Disconnected
                                                }
                                        }
                                    case None =>
                                        log.warn("Read ${buf[0..readCount]} is not a valid upstream shadowsocks packet")
                                        status = Status.Disconnected
                                }
                            } else {
                                break
                            }
                        }
                    }
                    let downwardRelay = spawn {
                        while (true) {
                            if (sock.isNone()) {
                                continue
                            }
                            let buf = Array<Byte>(4096, item: 0)
                            try {
                                let readCount = sock.getOrThrow().read(buf)
                                if (readCount != 0) {
                                    let packet = buildDownwardSsPacket(cryptor, buf[0..readCount])
                                    clientSock.write(packet)
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
                case Status.RelayUpwardFinished =>
                    log.debug("Status RelayUpwardFinished")
                    sock.getOrThrow().close()
                case Status.RelayDownwardFinished => 
                    log.debug("Status RelayDownwardFinished")
                    clientSock.close()
                    status = Status.Disconnected
                case Status.Disconnected =>
                    log.debug("Status Disconnected")
                    match (sock) {
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
                case Destory => 
                    log.debug("Status Destory")
                    break
            }

        }
    }
}