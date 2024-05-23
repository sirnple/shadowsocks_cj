package sirnple.shadowsocks.core

from std import log.*
from std import console.Console
from std import socket.*

public let ATYP_IPv4 = 0x01u8
public let ATYP_DOMAINNAME = 0x03u8
public let ATYP_IPv6 = 0x04u8

public let SOCKS_VERSION_5 = 0x05u8

public let METHOD_NOAUTH = 0x00u8
public let METHOD_GSSAPI = 0x01u8
public let METHOD_USERPASS = 0x02u8
public let METHOD_NOACCEPTABLE = 0xffu8

public let SUPPORT_AUTH_METHODS = [METHOD_NOAUTH, METHOD_GSSAPI, METHOD_USERPASS]

public func checkIsAuthRequest(frame: Array<Byte>): ?(Byte, Byte, Array<Byte>) {
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
    for (method in methods) {
        if (!SUPPORT_AUTH_METHODS.contains(method)) {
            return None
        }
    }
    return (ver, nmethods, methods)
}


public let NO_AUTH_RESPONSE = [SOCKS_VERSION_5, METHOD_NOAUTH]

public let CMD_CONNECT = 0x01u8
public let CMD_BIND = 0x02u8
public let CMD_UDP_ASSOCIATE = 0x03u8

public let RESERVED = 0x00u8
let log = SimpleLogger(@sourcePackage(), LOG_CONFIG.logLevel, Console.stdOut)
public func checkIsNegotiationRequest(frame: Array<Byte>): ?(Byte, Byte, Byte, Byte, Array<Byte>, Array<Byte>) {
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
        return (ver, cmd, rsv, atyp, frame[4..8], frame[8..10])
    }
    if (atyp == ATYP_IPv6) {
        if (frame.size != 22) {
            log.debug("Size of frame must be 22 when ATYP_IPv6, but is ${frame.size}")
            return None
        }
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

public let RELAY_BLOCK_SIZE = 65536

func tryResolveDomainName(domainName: Array<Byte>, port: Array<Byte>): ?(Byte, Array<Byte>) {
    log.debug((UInt16(port[0])<<8 | UInt16(port[1])).toString())
    let host = SocketAddress.resolve(String.fromUtf8(domainName), UInt16(port[0])<<8 | UInt16(port[1]))
    match (host) {
        case Some(h) =>
            log.debug("Resolve domain name ${String.fromUtf8(domainName)}:${UInt16(port[0])<<8 | UInt16(port[1])} to ${h.hostAddress}")
            match (h.kind) {
                case SocketAddressKind.IPv4 => (ATYP_IPv4, h.address)
                case SocketAddressKind.IPv6 => (ATYP_IPv6, h.address)
                case _ => 
                    log.debug("Address kind must be ${SocketAddressKind.IPv4} or ${SocketAddressKind.IPv6}, but is ${h.kind}")
                    None
            }
        case None => 
            println("=================== Can't resolve domain name ${String.fromUtf8(domainName)}:${UInt16(port[0])<<8 | UInt16(port[1])}")
            log.debug("=================== Can't resolve domain name ${String.fromUtf8(domainName)}:${UInt16(port[0])<<8 | UInt16(port[1])}")
            None
    }
}

public func buildNegotiationResponse(ver: Byte, rep: Byte, rsv: Byte, atyp: Byte, addr: Array<Byte>, port: Array<Byte>): Array<Byte> {
    return [ver, rep, rsv, atyp] + addr + port
}

public func buildSuccessNegotiationResponse(atyp: Byte, addr: Array<Byte>, port: Array<Byte>): Array<Byte> {
    return buildNegotiationResponse(SOCKS_VERSION_5, REP_SUCCEEDED, RESERVED, atyp, addr, port)
}

public func buildUpwardSsPacket(dstAddtr: DstAddr, cryptor: Cryptor, rawData: Array<Byte>): Array<Byte> {
    if (dstAddtr.atyp == ATYP_DOMAINNAME) {
        return match (tryResolveDomainName(dstAddtr.addr, dstAddtr.port)) {
            case Some((resolvedAtyp, resolvedAddr)) =>
                let (iv, encryptedData) = cryptor.encrypt([resolvedAtyp] + resolvedAddr + dstAddtr.port + rawData)
                [UInt8(iv.size)] + iv + encryptedData
            case None => 
                let (iv, encryptedData) = cryptor.encrypt([dstAddtr.atyp] + dstAddtr.addr + dstAddtr.port + rawData)
                [UInt8(iv.size)] + iv + encryptedData
        }
    }
    let (iv, encryptedData) = cryptor.encrypt([dstAddtr.atyp] + dstAddtr.addr + dstAddtr.port + rawData)
    [UInt8(iv.size)] + iv + encryptedData
}

public func buildDownwardSsPacket(cryptor: Cryptor, rawData: Array<Byte>): Array<Byte> {
    let (iv, encryptedData) = cryptor.encrypt(rawData)
    [UInt8(iv.size)] + iv + encryptedData
}


/** 
 * 解包 SS 包
 * @param cryptor 解密器
 * @param ssPacket SS 包，iv.len + iv + encryptedData
 * @return Some((iv, atyp, dst.addr, dst.port, data)) or None
 */
public func tryUnBuildSsPacket(cryptor: Cryptor, ssPacket: Array<Byte>): ?(Array<Byte>, Array<Byte>) {
    assert(ssPacket.size > IV_LEN + 1)
    if (ssPacket.size <= IV_LEN + 1) {
        log.debug("Unbuild SS packet failed, because invalid ssPacket, size must be greater than ${IV_LEN + 1}, but is ${ssPacket.size}")
        return None
    }
    let ivLen = ssPacket[0]
    if (ssPacket.size < Int64(ivLen) + 1) {
        log.debug("Unbuild SS packet failed, because invalid ssPacket, ivLen must be greater than ${Int64(ivLen) + 1}, but is ${ssPacket.size}")
        return None
    }
    let iv = ssPacket[1..Int64(ivLen) + 1]
    let decryptData = cryptor.decrypt(iv, ssPacket[Int64(ivLen) + 1..ssPacket.size])
    return (iv, decryptData)
}

