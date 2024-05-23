package sirnple.shadowsocks.local

import sirnple.shadowsocks.config.ShadowsocksConfig
import sirnple.shadowsocks.core.*
import sirnple.shadowsocks.util.assert

from std import socket.*
from std import log.*
from std import reflect.*
from std import console.Console

class TcpHandler {
    private static let log = SimpleLogger(TypeInfo.of<TcpHandler>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private var remoteSock: Option<TcpSocket> = None
    private var status: Status = Status.Init
    private var dstAddr: Option<DstAddr> = None

    public TcpHandler(let config: ShadowsocksConfig, let clientSock: TcpSocket, let cryptor: Cryptor) {
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
                    let upwardRelay = spawn {
                        while (true) {
                            let buf = Array<Byte>(RELAY_BLOCK_SIZE - IV_LEN - 1, item: 0)
                            let readCount = clientSock.read(buf)
                            if (readCount != 0) {
                                log.debug("Receive ${readCount} bytes from client")
                                let packet = buildSsPacket(buf[0..readCount])
                                assert(packet.size <= RELAY_BLOCK_SIZE, message: "Packet size is too large, max size is ${RELAY_BLOCK_SIZE}, but actual size is ${packet.size}")
                                remoteSock.getOrThrow().write(packet)
                                log.debug("Send ${packet.size} bytes to remote server")
                            } else {
                                break
                            }
                        }
                    }
                    let downwardRelay = spawn {
                        var iv: Option<Array<Byte>> = None
                        while (true) {
                            if (remoteSock.isNone()) {
                                continue
                            }
                            let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                            try {
                                let readCount = remoteSock.getOrThrow().read(buf)
                                if (readCount == 0) {
                                    break
                                }
                                log.debug("Receive ${readCount} bytes from remote server")
                                match (iv) {
                                    case Some(iv0) =>
                                        let decrypted = cryptor.decrypt(iv0, buf[0..readCount])
                                        clientSock.write(decrypted)
                                        log.debug("Send ${decrypted.size} bytes to client")
                                    case None =>
                                        if (let Some((iv0, decrypted)) <- tryUnBuildDownwardSsPacket(buf[0..readCount])) {
                                            iv = Some(iv0)
                                            clientSock.write(decrypted)
                                            log.debug("Send ${decrypted.size} bytes to client")
                                        } else {
                                            log.warn("Receive from remote server is not a valid downward ss packet, please try again, ${buf[0..readCount]}")
                                            break
                                        }
                                }
                            } catch (e: SocketException) {
                                if (e.message.contains("Socket is not connected") || e.message.contains("Socket is already closed")) {
                                    continue
                                } else {
                                    log.warn("Read from remote server failed, ${e.message}")
                                }
                            }
                        }
                    }
                    upwardRelay.get()
                    remoteSock.getOrThrow().close()
                    downwardRelay.get()
                    status = Disconnected
                case Disconnected =>
                    log.debug("Status Disconnected")
                    match (remoteSock) {
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

    private func buildSsPacket(rawData: Array<Byte>): Array<Byte> {
        return match (dstAddr) {
            case Some(addr) => buildUpwardSsPacket(addr, cryptor, rawData)
            case None => throw Exception("Illegal status, addres has not been negotiation yet")
        }
    }

    /** 
    * 解包 SS 包， 这里是下行的TCP包，没有包含有DST.ADDR和DST.PORT
    * @param cryptor 解密器
    * @param ssPacket SS 包，iv.len + iv + encryptedData
    * @return Some((iv, data)) or None
    */
    private func tryUnBuildDownwardSsPacket(ssPacket: Array<Byte>): ?(Array<Byte>, Array<Byte>) {
        tryUnBuildSsPacket(cryptor, ssPacket)
    }
}