package sirnple.shadowsocks.core

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

public func checkIsNegotiationRequest(frame: Array<Byte>): ?(Byte, Byte, Byte, Byte, Array<Byte>, Array<Byte>) {
    if (frame.size < 4) {
        return None
    }
    let ver = frame[0]
    if (ver != SOCKS_VERSION_5) {
        return None
    }
    let cmd = frame[1]
    if (cmd != CMD_CONNECT || cmd != CMD_BIND || cmd != CMD_UDP_ASSOCIATE) {
        return None
    }
    let rsv = frame[2]
    if (rsv != RESERVED) {
        return None
    }
    let atyp = frame[3]
    match (atyp) {
        case ATYP_IPv4 =>
            if (frame.size != 10) {
                return None
            }
            return (ver, cmd, rsv, atyp, frame[4..8], frame[8..10])
        case ATYP_DOMAINNAME =>
            if (frame.size < 5) {
                return None
            }
            let domainLen = frame[4]
            if (frame.size < 5 + Int64(domainLen) + 2) {
                return None
            }
            let domainName = frame[5..5 + Int64(domainLen)]
            let port = frame[5 + Int64(domainLen)..5 + Int64(domainLen) + 2]
            return (ver, cmd, rsv, atyp, [domainLen] + domainName, port)
        case ATYP_IPv6 =>
            if (frame.size != 22) {
                return None
            }
            return (ver, cmd, rsv, atyp, frame[4..20], frame[20..22])
        case _ => return None
    }
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