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
                    status = Status.Auth
                case Auth =>
                    log.debug("Status Auth")
                    let buf = Array<Byte>(AUTH_REQUEST_MAX_LEN, item: 0)
                    let readCount = clientSock.read(buf)
                    match (tryProcessSocks5AuthRequest(buf[0..readCount])) {
                        case Some(authResponse) => 
                            clientSock.write(authResponse)
                            status = Status.AddressNegotiationRequest
                        case None => 
                            log.warn("Auth: read ${buf[0..readCount]} is not a valid auth frame, please try again")
                            continue
                    }
                case AddressNegotiationRequest =>
                    log.debug("Status AddressNegotiationRequest")
                    let buf = Array<Byte>(ADDR_NEGOTIATE_MAX_LEN, item: 0)
                    let readCount = clientSock.read(buf)
                    match (tryProcessNegotiationRequest(buf[0..readCount])) {
                        case Some((ver, cmd, rsv, atyp, addr, port)) =>
                            dstAddr = Some(DstAddr(atyp, addr, port))
                            status = Status.AddressNegotiationResponse
                        case None => 
                            log.warn("Invalid status, bad address negotiation request")
                            status = Disconnected
                    }
                case AddressNegotiationResponse =>
                    log.debug("Status AddressNegotiationResponse")
                    match((dstAddr, remoteSock)) {
                        case (None, _) =>
                            log.warn("Invalid status, address negotiation not completed")
                            status = Disconnected
                        case (Some(addr), _) =>
                            let newRemoteSock = TcpSocket(SocketAddress(config.server, config.serverPort))
                            newRemoteSock.connect()
                            remoteSock = Some(newRemoteSock)
                            let bindAddr = newRemoteSock.localAddress.address
                            let bindPort = newRemoteSock.localAddress.port
                            let bindAtyp = match (newRemoteSock.localAddress.kind) {
                                case SocketAddressKind.IPv4 => ATYP_IPv4
                                case SocketAddressKind.IPv6 => ATYP_IPv6
                                case _ => throw Exception("Should never happen")
                            }
                            clientSock.write(buildSuccessNegotiationResponse(bindAtyp, bindAddr, [UInt8(bindPort>>8), UInt8(bindPort&0xff)]))
                            status = Connected
                    }
                case Connected =>
                    log.debug("Status Connected")
                    let upwardRelay = spawn {
                        var sendIv = None<Array<Byte>>
                        while (true) {
                            match ((sendIv, remoteSock)) {
                                case (_, None) =>
                                    log.debug("Invalid status, ss-remote is not ready")
                                    break
                                case (None, Some(sock)) =>
                                    // send first packet
                                    let buf = Array<Byte>(SS_LOCAL_FIRST_SEND_PAYLOAD_MAX_SIZE, item: 0)
                                    let readCount = clientSock.read(buf)
                                    if (readCount == 0) {
                                        log.debug("Client socket is closed and nothing is relayed")
                                        break
                                    }
                                    log.debug("Receive first packet from client, ${readCount} bytes\nbefore encrypted: ${buf[0..readCount]}")
                                    let (iv, packet) = packSsLocalSendFirstSsPacket(dstAddr.getOrThrow(), cryptor, buf[0..readCount])
                                    sock.write(packet)
                                    log.debug("Send first packet to ss-remote, ${packet.size} bytes\nafter encrypted: ${packet[0..packet.size]}")
                                    sendIv = Some(iv)
                                case (Some(iv), Some(sock)) =>
                                    // send follow packet
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    let readCount = clientSock.read(buf)
                                    if (readCount != 0) {
                                        log.debug("Receive follow packet from client, ${readCount} bytes\nbefore encrypted: ${buf[0..readCount]}")
                                        let packet = packFollowSsPacket(cryptor, iv: iv, rawData: buf[0..readCount])
                                        sock.write(packet)
                                        log.debug("Send follow packet to ss-remote, ${packet.size} bytes\nafter encrypted: ${packet[0..packet.size]}")
                                    } else {
                                        break
                                    }
                            }
                        }
                    }

                    let downwardRelay = spawn {
                        var receivedIv = None<Array<Byte>>
                        while (true) {
                            match ((receivedIv, remoteSock)) {
                                case (_, None) =>
                                    log.debug("Invalid status, ss-remote is not ready")
                                    break
                                case (None, Some(sock)) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    let readCount = sock.read(buf)
                                    if (readCount == 0) {
                                        log.debug("ss-remote is closed")
                                        break
                                    }
                                    log.debug("Receive first packet from ss-remote, ${readCount} bytes\nbefore decrypted: ${buf[0..readCount]}")
                                    match (tryUnpackSsLocalFirstReceivedPacket(cryptor, buf[0..readCount])) {
                                        case Some((iv, payload)) =>
                                            receivedIv = Some(iv)
                                            clientSock.write(payload)
                                            log.debug("Send first packet to client, ${payload.size} bytes\nafter decrypted: ${payload[0..payload.size]}")
                                        case None =>
                                            log.warn("Invalid first packet from ss-remote")
                                            break
                                    }
                                case (Some(iv), Some(sock)) =>
                                    let buf = Array<Byte>(RELAY_BLOCK_SIZE, item: 0)
                                    try {
                                        let readCount = sock.read(buf)
                                        if (readCount == 0) {
                                            log.debug("ss-remote is closed")
                                            break
                                        }
                                        log.debug("Receive follow packet from ss-remote, ${readCount} bytes\nbefore decrypted: ${buf[0..readCount]}")
                                        let payload = tryUnpackSsLocalFollowReceivedPacket(cryptor, iv, buf[0..readCount])
                                        clientSock.write(payload)
                                        log.debug("Send follow packet to client, ${payload.size} bytes\nafter decrypted: ${payload[0..payload.size]}")
                                    } catch (e: SocketException) {
                                        if (e.message.contains("Socket is not connected") || e.message.contains("Socket is already closed")) {
                                            continue
                                        } else {
                                            log.warn("Read from ss-remote failed, ${e.message}")
                                        }
                                    }
                            }
                        }
                    }
                    upwardRelay.get()
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
}