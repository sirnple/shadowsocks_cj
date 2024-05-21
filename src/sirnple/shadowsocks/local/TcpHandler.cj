package sirnple.shadowsocks.local

import sirnple.shadowsocks.config.Config
import sirnple.shadowsocks.core.*
import sirnple.shadowsocks.util.assert

from std import socket.*
from std import log.*
from std import reflect.*
from std import console.Console

class TcpHandler {
    private static let log = SimpleLogger(TypeInfo.of<TcpHandler>().qualifiedName, LogLevel.ALL, Console.stdOut)
    private var remoteSock: Option<TcpSocket> = None
    private var status: Status = Status.Init
    private var dstAddr: Option<DstAddr> = None

    public TcpHandler(let config: Config, let clientSock: TcpSocket, let cryptor: Cryptor) {
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
                    status = Status.AuthRequest
                case AuthRequest =>
                    log.debug("Status AuthRequest")
                    let buf = Array<Byte>(257, item: 0)
                    let readCount = clientSock.read(buf)
                    match (checkIsAuthRequest(buf[0..readCount])) {
                        case Some(_) => status = Status.AuthResponse
                        case None => 
                            log.warn("AuthRequest: read ${buf[0..readCount]} is not a valid auth frame, please try again")
                            continue
                    }
                case AuthResponse =>
                    log.debug("Status AuthResponse")
                    clientSock.write(NO_AUTH_RESPONSE)
                    status = Status.AddressNegotiationRequest
                case AddressNegotiationRequest =>
                    log.debug("Status AddressNegotiationRequest")
                    let buf = Array<Byte>(100, item: 0)
                    let readCount = clientSock.read(buf)
                    match (checkIsNegotiationRequest(buf[0..readCount])) {
                        case Some((ver, cmd, rsv, atyp, addr, port)) =>
                            dstAddr = Some(DstAddr(atyp, addr, port))
                            status = Status.AddressNegotiationResponse
                        case None => 
                            log.warn("AddressNegotiationRequest: read ${buf[0..readCount]} is not a valid address negotiation frame, please try again")
                            continue
                    }
                case AddressNegotiationResponse =>
                    log.debug("Status AddressNegotiationResponse")
                    match(dstAddr) {
                        case Some(addr) => 
                            remoteSock = TcpSocket(SocketAddress(config.server, config.serverPort))
                            remoteSock.getOrThrow().connect()
                            let bindAddr = remoteSock.getOrThrow().localAddress.address
                            let bindPort = remoteSock.getOrThrow().localAddress.port
                            clientSock.write(buildSuccessNegotiationResponse(addr.atyp, bindAddr, [UInt8(bindPort>>8), UInt8(bindPort&0xff)]))
                            status = Status.Connected
                        case None => 
                            log.warn("AddressNegotiationResponse: dstAddr is None, need to wait for AddressNegotiationRequest")
                            status = Status.AddressNegotiationRequest
                    }
                case Connected =>
                    log.debug("Status Connected")
                    let buf = Array<Byte>(4096, item: 0)
                    let readCount = clientSock.read(buf)
                    if (readCount != 0) {
                        let packet = buildSsPacket(buf[0..readCount])
                        remoteSock.getOrThrow().write(packet)
                    } else {
                        status = RelayUpwardFinished
                    }
                case RelayUpwardFinished =>
                    log.debug("Status RelayUpwardFinished")
                    remoteSock.getOrThrow().close()
                    let buf = Array<Byte>(4096, item: 0)
                    let readCount = remoteSock.getOrThrow().read(buf)
                    if(readCount != 0) {
                        clientSock.write(unBuildSsPacket(buf[0..readCount]))
                    } else {
                        status = Status.RelayDownwardFinished
                    }
                case RelayDownwardFinished =>
                    log.debug("Status RelayDownwardFinished")
                    clientSock.close()
                    status = Status.Disconnected
                case Disconnected =>
                    log.debug("Status Disconnected")
                    match (remoteSock) {
                        case Some(s) => s.close()
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

    private func buildSsPacket(rawData: Array<Byte>): Array<Byte> {
        return match (dstAddr) {
            case Some(addr) => buildUpwardSsPacket(addr, cryptor, rawData)
            case None => throw Exception("Illegal status, addres has not been negotiation yet")
        }
    }

    private func unBuildSsPacket(ssPacket: Array<Byte>): Array<Byte> {
        return unBuildDownwardSsPacket(cryptor, ssPacket)
    }
}