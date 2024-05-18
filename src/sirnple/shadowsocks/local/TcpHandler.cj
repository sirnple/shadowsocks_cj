package sirnple.shadowsocks.local

import sirnple.shadowsocks.config.Config
import sirnple.shadowsocks.core.*

from std import socket.*
from std import log.*
from std import reflect.*
from std import console.Console

class TcpHandler {
    private static let log = SimpleLogger(TypeInfo.of<TcpHandler>().qualifiedName, LogLevel.ALL, Console.stdOut)
    private var remoteSock: Option<TcpSocket> = None
    private var status: Status = Status.Init
    private var dstAddr: Option<DstAddr> = None

    public TcpHandler(let config: Config, let clientSock: TcpSocket) {
    }

    public func handle() {
        spawn {
            while(true) {
                match(status) {
                    case Status.Init => 
                        // 确保socket可用
                        log.debug("Status Init")
                        assert(!clientSock.isClosed(), message: "Connection with client is broken, socket is closed")
                        status = Status.AuthRequest
                    case AuthRequest =>
                        log.debug("Status AuthRequest")
                        let buf = Array<Byte>(257, item: 0)
                        let readCount = clientSock.read(buf)
                        log.debug("AuthRequest: read ${readCount} bytes, read data is ${buf}")
                        let ver = buf[0]
                        let nmethods = buf[1]
                        let methods = buf[2..Int64(nmethods)]
                        assert(ver == 0x05)
                        assert(nmethods == 0x01 && methods[0] == 0x00, message: "AuthRequest: auth method, 0x00(No Auth) is the only support one auth method by now")
                        assert(readCount == Int64(nmethods) + 2)
                        // todo: support more authmethods
                        status = Status.AuthResponse
                    case AuthResponse =>
                        log.debug("Status AuthResponse")
                        clientSock.write([SOCKS_VERSION_5, METHOD_NOAUTH])
                        status = Status.AddressNegotiationRequest
                    case AddressNegotiationRequest =>
                        log.debug("Status AddressNegotiationRequest")
                        let buf = Array<Byte>(100, item: 0)
                        let readCount = clientSock.read(buf)
                        let ver = buf[0]
                        assert(ver == SOCKS_VERSION_5)
                        let cmd = buf[1]
                        assert(cmd == CMD_BIND, message: "Only support cmd: ${CMD_BIND}, e.g. tcp")
                        let rsv = buf[2]
                        assert(rsv == RESERVED, message: "Reserved only support ${RESERVED}")
                        let atyp = buf[3]
                        assert(atyp == ATYP_IPv4, message: "Only support atyp: 0x01, e.g. ipv4")
                        let addr = buf[4..8] // ipv4 address 
                        let port = buf[8..10] // port
                        assert(readCount == 10)
                        dstAddr = Some(DstAddr(ATYP_IPv4, addr, port))
                        status = Status.AddressNegotiationResponse
                    case AddressNegotiationResponse =>
                        log.debug("Status AddressNegotiationResponse")
                        match(dstAddr) {
                            case Some(addr) => 
                                remoteSock = TcpSocket(SocketAddress(config.server, config.port))
                                let bindAddr = remoteSock.getOrThrow().localAddress.address
                                let bindPort = remoteSock.getOrThrow().localAddress.port
                                clientSock.write([SOCKS_VERSION_5, REP_SUCCEEDED, RESERVED, addr.atyp] + bindAddr + [UInt8(bindPort>>8), UInt8(bindPort&0xff)])
                                status = Status.Connected
                            case None => throw Exception("Illegal status, addres has not been negotiation yet")
                        }
                    case Connected =>
                        log.debug("Status Connected")
                        let buf = Array<Byte>(4096, item: 0)
                        let readCount = clientSock.read(buf)
                        if (readCount != 0) {
                            remoteSock.getOrThrow().write(buildSsPacket(buf[0..readCount]))
                        } else {
                            status = RelayUpwardFinished
                        }
                    case RelayUpwardFinished =>
                        log.debug("Status LocalClientClosed")
                        remoteSock.getOrThrow().close()
                        let buf = Array<Byte>(4096, item: 0)
                        let readCount = remoteSock.getOrThrow().read(buf)
                        if(readCount != 0) {
                            clientSock.write(decrypt(buf[0..readCount]))
                        } else {
                            status = Status.RelayDownwardFinished
                        }
                    case RelayDownwardFinished =>
                        log.debug("Status RelayDownwardFinished")
                        clientSock.close()
                        status = Status.Disconnected
                    case Disconnected =>
                        log.debug("Status Disconnected")
                        status = Status.Destory
                    case _ => throw Exception("Not support destory resources")
                }
            }
        }
    }

    private func encrypt(buf: Array<Byte>): Array<Byte> {
        // 等长加密
        return buf
    }

    private func buildSsPacket(iv: Array<Byte>, rawData: Array<Byte>): Array<Byte> {
        return match (dstAddr) {
            case Some(addr) => [UInt8(iv.size)] + iv + encrypt(addr.toBytes() + rawData)
            case None => throw Exception("Illegal status, addres has not been negotiation yet")
        }
    }

    private func decrypt(buf: Array<Byte>): Array<Byte> {
        // 等长解密
        return buf
    }
}

enum Status {
    | Init
    | AuthRequest
    | AuthResponse
    | AddressNegotiationRequest
    | AddressNegotiationResponse
    | Connected         // 上行和下行转发都通
    | RelayUpwardFinished // 上行转发数据完成
    | RelayDownwardFinished      // 下行转发数据完成
    | Disconnected      // 本地应用和远端SS服务都关闭
    | Destory           // 回收资源
}

struct DstAddr {
    public DstAddr(public let atyp: Byte, public let addr: Array<Byte>, public let port: Array<Byte>) {

    }

    public func toBytes(): Array<Byte> {
        return [atyp] + addr + port
    }
}