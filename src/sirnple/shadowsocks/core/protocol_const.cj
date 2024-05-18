package sirnple.shadowsocks.core

public let ATYP_IPv4 = 0x01u8
public let ATYP_DOMAINNAME = 0x03u8
public let ATYP_IPv6 = 0x04u8

public let SOCKS_VERSION_5 = 0x05u8

public let METHOD_NOAUTH = 0x00u8
public let METHOD_GSSAPI = 0x01u8
public let METHOD_USERPASS = 0x02u8
public let METHOD_NOACCEPTABLE = 0xffu8

public let CMD_CONNECT = 0x01u8
public let CMD_BIND = 0x02u8
public let CMD_UDP_ASSOCIATE = 0x03u8

public let RESERVED = 0x00u8

public let REP_SUCCEEDED = 0x00u8
public let REP_GENERAL_FAILURE = 0x01u8
public let REP_CONNECTION_NOT_ALLOWED = 0x02u8
public let REP_NETWORK_UNREACHABLE = 0x03u8
public let REP_HOST_UNREACHABLE = 0x04u8
public let REP_CONNECTION_REFUSED = 0x05u8
public let REP_TTL_EXPIRED = 0x06u8
public let REP_COMMAND_NOT_SUPPORTED = 0x07u8
public let REP_ADDRESS_TYPE_NOT_SUPPORTED = 0x08u8