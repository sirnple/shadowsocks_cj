package sirnple.shadowsocks.core

from std import log.*
from std import console.Console

public let ATYP_IPv4 = 0x01u8
public let ATYP_DOMAINNAME = 0x03u8
public let ATYP_IPv6 = 0x04u8

public func testMatch(atype: Byte) {
    match (atype) {
        case ATYP_IPv4 => 
            print("ATYP_IPv4")
        case ATYP_DOMAINNAME => 
            print("ATYP_DOMAINNAME")
        case ATYP_IPv6 => 
            print("ATYP_IPv6")
        case _ => 
            print("Unknown ATYP")
    }
    match (atype) {
        case 0x01u8 => 
            print("0x01u8")
        case 0x03u8 => 
            print("0x03u8")
        case 0x04u8 => 
            print("0x04u8")
        case _ => 
            print("Unknown ATYP")
    }
}

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
let log = SimpleLogger(@sourcePackage(), DEBUG, Console.stdOut)
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
        return (ver, cmd, rsv, atyp, [domainLen] + domainName, port)
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


public func buildNegotiationResponse(ver: Byte, rep: Byte, rsv: Byte, atyp: Byte, addr: Array<Byte>, port: Array<Byte>): Array<Byte> {
    return [ver, rep, rsv, atyp] + addr + port
}

public func buildSuccessNegotiationResponse(atyp: Byte, addr: Array<Byte>, port: Array<Byte>): Array<Byte> {
    return buildNegotiationResponse(SOCKS_VERSION_5, REP_SUCCEEDED, RESERVED, atyp, addr, port)
}

public func buildUpwardSsPacket(dstAddtr: DstAddr, cryptor: Cryptor, rawData: Array<Byte>): Array<Byte> {
    log.debug("Before encrypt: ${[dstAddtr.atyp] + dstAddtr.addr + dstAddtr.port + rawData}")
    let (iv, encryptedData) = cryptor.encrypt([dstAddtr.atyp] + dstAddtr.addr + dstAddtr.port + rawData)
    log.debug("After encrypt: ${encryptedData}")
    [UInt8(iv.size)] + iv + encryptedData
}

public func buildDownwardSsPacket(cryptor: Cryptor, rawData: Array<Byte>): Array<Byte> {
    log.debug("Before encrypt: ${rawData}")
    let (iv, encryptedData) = cryptor.encrypt(rawData)
    log.debug("After encrypt: ${encryptedData}")
    [UInt8(iv.size)] + iv + encryptedData
}


public func unBuildSsPacket(cryptor: Cryptor, ssPacket: Array<Byte>): Array<Byte> {
    log.debug("Before decrypt: ${ssPacket}")
    let ivLen = ssPacket[0]
    let iv = ssPacket[1..Int64(ivLen) + 1]
    let decryptData = cryptor.decrypt(iv, ssPacket[Int64(ivLen) + 1..ssPacket.size])
    log.debug("After decrypt: ${decryptData}")
    return decryptData
}

public func unBuildUpwardSsPacket(cryptor: Cryptor, ssPacket: Array<Byte>): ?(Byte, Array<Byte>, Array<Byte>, Array<Byte>) {
    let data = unBuildSsPacket(cryptor, ssPacket)
    let atyp = data[0]
    if (atyp == ATYP_IPv4) {
        return (atyp, data[1..5], data[5..7], data[7..data.size])
    }
    if (atyp == ATYP_IPv6) {
        return (atyp, data[1..17], data[17..19], data[19..data.size])
    }
    if (atyp == ATYP_DOMAINNAME) {
        return (atyp, data[1..2], data[2..4], data[4..data.size])
    }
    log.debug("ATYP must be ${ATYP_IPv4}, ${ATYP_DOMAINNAME}, or ${ATYP_IPv6}, but is ${atyp}")
    return None
}

public func unBuildDownwardSsPacket(cryptor: Cryptor, ssPacket: Array<Byte>): Array<Byte> {
    unBuildSsPacket(cryptor, ssPacket)
}