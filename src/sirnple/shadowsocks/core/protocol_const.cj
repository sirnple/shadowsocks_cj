package shadowsocks_cj.sirnple.shadowsocks.core

import std.log.SimpleLogger
import std.console.Console
import std.socket.{SocketAddress, SocketAddressKind}
import shadowsocks_cj.sirnple.shadowsocks.config.LOG_CONFIG

public const ATYP_IPv4 = 0x01u8
public const ATYP_DOMAINNAME = 0x03u8
public const ATYP_IPv6 = 0x04u8

public const SOCKS_VERSION_5 = 0x05u8

public const METHOD_NOAUTH = 0x00u8
public const METHOD_GSSAPI = 0x01u8
public const METHOD_USERPASS = 0x02u8
public const METHOD_NOACCEPTABLE = 0xffu8

public let SUPPORT_AUTH_METHODS = [METHOD_NOAUTH, METHOD_GSSAPI, METHOD_USERPASS]
public const AUTH_REQUEST_MAX_LEN = 1 + 1 + 255

/** 
 * 校验Socks5的认证请求，并且返回响应
 * Request:
 * +----+----------+---------+
 * |VER | NMETHODS | METHODS |
 * +----+----------+---------+
 * | 1B |    1B    |1 to 255B|
 * +----+----------+---------+
 * NMETHODS: 客户端支持的认证方式的个数
 * METHODS: 客户端支持的认证方式数组
 * Response:
 * +----+--------+
 * |VER | METHOD |
 * +----+--------+
 * | 1B |   1B   |
 * +----+--------+
 * METHOD: 服务端返回的认证方式
 *
 * @param frame: Socks5的认证请求
 * @return (ver, method)
 */
public func tryProcessSocks5AuthRequest(frame: Array<Byte>): ?Array<Byte> {
    if (frame.size < 3) {
        return None
    }
    let ver = frame[0]
    if (ver != SOCKS_VERSION_5) {
        return None
    }
    let nmethods = frame[1]
    if (Int64(nmethods) > SUPPORT_AUTH_METHODS.size || Int64(nmethods) == 0) {
        return None
    }
    if (frame.size < Int64(nmethods) + 2) {
        return None
    }

    let methods = frame[2..Int64(nmethods) + 2]
    let intersection = SUPPORT_AUTH_METHODS.intersection(methods)
    return if (intersection.isEmpty()) {
        [ver, METHOD_NOACCEPTABLE]
    } else {
        [ver, intersection[0]]
    }
}


public let NO_AUTH_RESPONSE = [SOCKS_VERSION_5, METHOD_NOAUTH]

public const CMD_CONNECT = 0x01u8
public const CMD_BIND = 0x02u8
public const CMD_UDP_ASSOCIATE = 0x03u8

public const RESERVED = 0x00u8
public const ADDR_NEGOTIATE_MAX_LEN = 1 + 1 + 1 + 1 + 1 + 255 + 2
let log = SimpleLogger(@sourcePackage(), LOG_CONFIG.logLevel, Console.stdOut)

/** 
 * 校验Socks5的地址协商请求，并且返回响应
 * Request:
 * +----+-----+-------+------+----------+----------+
 * |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
 * +----+-----+-------+------+----------+----------+
 * | 1B |  1B |  1B   |  1B  | Variable |    2B    |
 * +----+-----+-------+------+----------+----------+
 * Response:
 * +----+-----+-------+------+----------+----------+
 * |VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
 * +----+-----+-------+------+----------+----------+
 * | 1B |  1B |  1B   |  1B  | Variable |    2B    |
 * +----+-----+-------+------+----------+----------+
 *
 * @attention: 当atyp为DOMAINNAME时，DST.ADDR为1B的域名长度+域名
 * @param frame: Socks5的地址协商请求
 * @return (ver, rep, rsv, atyp, addr, port)
 */
public func tryProcessNegotiationRequest(frame: Array<Byte>): ?(ver: Byte, rep: Byte, rsv: Byte, atyp: Byte, addr: Array<Byte>, port: Array<Byte>) {
    if (frame.size < 4) {
        log.debug("Size of frame must be at least 4, but is ${frame.size}")
        return None
    }
    let ver = frame[0]
    if (ver != SOCKS_VERSION_5) {
        log.debug("Version must be ${SOCKS_VERSION_5}, but is ${ver}")
        return None
    }
    let cmd = frame[1]
    if (cmd != CMD_CONNECT && cmd != CMD_BIND && cmd != CMD_UDP_ASSOCIATE) {
        log.debug("Command must be ${CMD_CONNECT}, ${CMD_BIND}, or ${CMD_UDP_ASSOCIATE}, but is ${cmd}")
        return None
    }
    let rsv = frame[2]
    if (rsv != RESERVED) {
        log.debug("Reserved must be ${RESERVED}, but is ${rsv}")
        return None
    }
    let atyp = frame[3]
    if (atyp == ATYP_IPv4) {
        if (frame.size != 10) {
            log.debug("Size of frame must be 10 when ATYP_IPv4, but is ${frame.size}")
            return None
        }
        log.debug("Address negotiation dst address is ${SocketAddress(IPv4, frame[4..8], UInt16(frame[8])<<8 | UInt16(frame[9]))}")
        return (ver, cmd, rsv, atyp, frame[4..8], frame[8..10])
    }
    if (atyp == ATYP_IPv6) {
        if (frame.size != 22) {
            log.debug("Size of frame must be 22 when ATYP_IPv6, but is ${frame.size}")
            return None
        }
        log.debug("Address negotiation dst address is ${SocketAddress(IPv6, frame[4..20], UInt16(frame[20])<<8 | UInt16(frame[21]))}")
        return (ver, cmd, rsv, atyp, frame[4..20], frame[20..22])
    }
    if (atyp == ATYP_DOMAINNAME) {
        if (frame.size < 5) {
            log.debug("Size of frame must be at least 5 when ATYP_DOMAINNAME, but is ${frame.size}")
            return None
        }
        let domainLen = frame[4]
        if (frame.size != 5 + Int64(domainLen) + 2) {
            log.debug("Size of frame must be ${5 + domainLen + 2} when ATYP_DOMAINNAME, but is ${frame.size}")
            return None
        }
        let domainName = frame[5..5 + Int64(domainLen)]
        let port = frame[5 + Int64(domainLen)..5 + Int64(domainLen) + 2]
        log.debug("Address negotiation dst address is ${String.fromUtf8(domainName)}:${UInt16(port[0])<<8 | UInt16(port[1])}")
        return (ver, cmd, rsv, atyp, domainName, port)
    }
    log.debug("ATYP must be ${ATYP_IPv4}, ${ATYP_DOMAINNAME}, or ${ATYP_IPv6}, but is ${atyp}")
    return None
}

public let REP_SUCCEEDED = 0x00u8
public let REP_GENERAL_FAILURE = 0x01u8
public let REP_CONNECTION_NOT_ALLOWED = 0x02u8
public let REP_NETWORK_UNREACHABLE = 0x03u8
public let REP_HOST_UNREACHABLE = 0x04u8
public let REP_CONNECTION_REFUSED = 0x05u8
public let REP_TTL_EXPIRED = 0x06u8
public let REP_COMMAND_NOT_SUPPORTED = 0x07u8
public let REP_ADDRESS_TYPE_NOT_SUPPORTED = 0x08u8

public const RELAY_BLOCK_SIZE = 2048

func buildNegotiationResponse(ver: Byte, rep: Byte, rsv: Byte, atyp: Byte, addr: Array<Byte>, port: Array<Byte>): Array<Byte> {
    return [ver, rep, rsv, atyp] + addr + port
}

public func buildSuccessNegotiationResponse(atyp: Byte, addr: Array<Byte>, port: Array<Byte>): Array<Byte> {
    return buildNegotiationResponse(SOCKS_VERSION_5, REP_SUCCEEDED, RESERVED, atyp, addr, port)
}
public const ADDR_MAX_LEN = 1 + 1 + 255 + 2 // 地址最大长度是当atyp为DOMAINNAME时: 1B的atyp + 1B的addrLen + 255B的addr + 2B的port
public const ADDR_MIN_LEN = 1 + 4 + 2 // 地址最小长度是当atyp为IPV4时: 1B的atyp + 4B的addr + 2B的port
// ss-local发送的第一个报文能带的payload最大值，因为发送的第一个报文要带iv和地址，所以这里减掉的iv和地址
public const SS_LOCAL_FIRST_SEND_PAYLOAD_MAX_SIZE = RELAY_BLOCK_SIZE - IV_LEN - ADDR_MAX_LEN
/**
 * 构造ss-local to ss-remote的第一个SS包
 * (packet)格式:
 * +------------------------------+
 * | atyp | addr | port | payload |
 * +------------------------------+
 * |  1B  | varB |  2B  |   varB  |
 * +------------------------------+
 * 
 * @attention 当atyp == DOMAINNAME时，addr为域名长度+域名
 * @return ss-local to ss-remote的第一个包
 */
public func packSsLocalSendFirstSsPacket(dstAddtr: DstAddr, payload: Array<Byte>): Array<Byte> {
    if (dstAddtr.atyp == ATYP_IPv4 || dstAddtr.atyp == ATYP_IPv6) {
        return [dstAddtr.atyp] + dstAddtr.addr + dstAddtr.port + payload
    }
    if (dstAddtr.atyp == ATYP_DOMAINNAME) {
        return [dstAddtr.atyp] + [UInt8(dstAddtr.addr.size)] + dstAddtr.addr + dstAddtr.port + payload
    }

    log.debug("ATYP must be ${ATYP_IPv4}, ${ATYP_DOMAINNAME}, or ${ATYP_IPv6}, but is ${dstAddtr.atyp}")
    throw Exception("Should never happen")
}
// ss-local收到的第一个报文的最小值，也就是只有iv，没有payload
public const SS_LOCAL_FIRST_RECEIVED_PACKET_MIN_SIZE = IV_LEN
// ss-remote收到的第一个报文的最小值，也就是只有iv和地址，没有payload
public const SS_REMOTE_FIRST_RECEIVED_PACKET_MIN_SIZE = IV_LEN + ADDR_MIN_LEN
public const SS_FIRST_RECEIVED_PACKET_MIN_SIZE = SS_LOCAL_FIRST_RECEIVED_PACKET_MIN_SIZE

/**
 * 解析ss-local to ss-remote的第一个SS报文
 * 报文(packet)格式:
 * +------------------------------+
 * | atyp | addr | port | payload |
 * +------------------------------+
 * |            var B             |
 * +------------------------------+
 * ss-remote接收到第一个报文后，会存储iv和地址，后续的报文都会使用这个iv和地址
 * 
 * @attention 当atyp == DOMAINNAME时，addr为域名长度+域名
 * @return ?(iv: Array<Byte>, atyp: Byte, dstAddr: Array<Byte>, dstPort: Array<Byte>, payload: Array<Byte>) 
 */
public func tryUnpackSsRemoteFirstReceivedPacket(ssRemoteFirstReceivedDecryptedData: Array<Byte>): ?(atyp: Byte, dstAddr: Array<Byte>, dstPort: Array<Byte>, payload: Array<Byte>) {
    if (ssRemoteFirstReceivedDecryptedData.size <= ADDR_MIN_LEN) {
        return None
    }
    let atyp = ssRemoteFirstReceivedDecryptedData[0]
    if (atyp == ATYP_IPv4) {
        return (atyp, ssRemoteFirstReceivedDecryptedData[1..5], ssRemoteFirstReceivedDecryptedData[5..7], ssRemoteFirstReceivedDecryptedData[7..ssRemoteFirstReceivedDecryptedData.size])
    }
    if (atyp == ATYP_IPv6) {
        return (atyp, ssRemoteFirstReceivedDecryptedData[1..17], ssRemoteFirstReceivedDecryptedData[17..19], ssRemoteFirstReceivedDecryptedData[19..ssRemoteFirstReceivedDecryptedData.size])
    }
    if (atyp == ATYP_DOMAINNAME) {
        // data格式: atyp + domainNameLen + domainName + port + payload
        let domainNameLen = ssRemoteFirstReceivedDecryptedData[1]
        let domainName = ssRemoteFirstReceivedDecryptedData[2..Int64(domainNameLen) + 2]
        let port = ssRemoteFirstReceivedDecryptedData[Int64(domainNameLen) + 2..Int64(domainNameLen) + 4]
        let payload = ssRemoteFirstReceivedDecryptedData[Int64(domainNameLen) + 4..ssRemoteFirstReceivedDecryptedData.size]
        return (atyp, domainName, port, payload)
    }
    log.warn("ATYP must be ${ATYP_IPv4}, ${ATYP_DOMAINNAME}, or ${ATYP_IPv6}, but is ${atyp}")
    return None
}
// ss-remote收到的第一个报文能带的payload的最大值，和ss-local发送的第一个报文的payload一样
public const SS_REMOTE_FIRST_RECEIVED_PAYLOAD_MAX_SIZE = SS_LOCAL_FIRST_SEND_PAYLOAD_MAX_SIZE 
// ss-remote发送的第一个报文能带的payload最大值，因为发送的第一个报文要带iv，所以这里减掉iv
public const SS_REMOTE_FIRST_SEND_PAYLOAD_MAX_SIZE = RELAY_BLOCK_SIZE - IV_LEN

/**
 * 解析第一个加密包
 * (packet)格式：
 * +------------------------+
 * | iv  | encryptedPayload |
 * +------------------------+
 * | 16B |      varB        |
 * +------------------------+
 *
 * @return ?(iv: Array<Byte>, encryptedPayload: Array<Byte>)
 */
public func tryUnpackFirstEncryptedPacket(ssLocalFirstReceivedPacket: Array<Byte>): ?(iv: Array<Byte>, encryptedPayload: Array<Byte>) {
    if (ssLocalFirstReceivedPacket.size < SS_FIRST_RECEIVED_PACKET_MIN_SIZE) {
        return None
    }
    let iv = ssLocalFirstReceivedPacket[0..IV_LEN]
    let encryptedPayload = ssLocalFirstReceivedPacket[IV_LEN..ssLocalFirstReceivedPacket.size]
    (iv, encryptedPayload)
}