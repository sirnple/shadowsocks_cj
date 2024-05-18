package sirnple.shadowsocks.core

enum Socks5Frame {
    /* 
     * +----+----------+----------+
     * |VER | NMETHODS | METHODS  |
     * +----+----------+----------+
     * | 1  |    1     | 1 to 255 |
     * +----+----------+----------+
     * VER     protocol version: X'05'
     * NMETHODS  number of methods
     * METHODS   authentication methods supported
     *  X'00' NO AUTHENTICATION REQUIRED
     *  X'01' GSSAPI
     *  X'02' USERNAME/PASSWORD
     *  X'03' to X'7F' IANA ASSIGNED
     *  X'80' to X'FE' RESERVED FOR PRIVATE METHODS
     *  X'FF' NO ACCEPTABLE METHODS
     */
    | AuthRequestFrame(Byte, Byte, Array<Byte>)   // 协商认证方法的请求
    /* 
     * +----+--------+
     * |VER | METHOD |
     * +----+--------+
     * | 1  |   1    |
     * +----+--------+
     * VER    protocol version: X'05'
     * METHOD  authentication method
     *  X'00' NO AUTHENTICATION REQUIRED
     *  X'01' GSSAPI
     *  X'02' USERNAME/PASSWORD
     *  X'03' to X'7F' IANA ASSIGNED
     *  X'80' to X'FE' RESERVED FOR PRIVATE METHODS
     *  X'FF' NO ACCEPTABLE METHODS
     */
    | AuthResponseFrame(Byte, Byte)               // 协商认证方法的相应
    /* 
     * +----+-----+-------+------+----------+----------+
     * |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
     * +----+-----+-------+------+----------+----------+
     * | 1  |  1  | X'00' |  1   | Variable |    2     |
     * +----+-----+-------+------+----------+----------+
     * VER     protocol version: X'05'
     * CMD     CONNECT X'01', BIND X'02', UDP ASSOCIATE X'03'
     * RSV     RESERVED
     * ATYP   address type of following address
     *  IP V4 address: X'01'
     *  DOMAINNAME: X'03'
     *  IP V6 address: X'04'
     * DST.ADDR resolved address
     * DST.PORT destination port in network octet order
     */
    | AddressNegotiationRequestFrame(Byte, Byte, Byte, Byte, Array<Byte>, Int16)
    /* 
     * +----+-----+-------+------+----------+----------+
     * |VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
     * +----+-----+-------+------+----------+----------+
     * | 1  |  1  | X'00' |  1   | Variable |    2     |
     * +----+-----+-------+------+----------+----------+
     * VER     protocol version: X'05'
     * REP     reply field:
     *  X'00' succeeded
     *  X'01' general SOCKS server failure
     *  X'02' connection not allowed by ruleset
     *  X'03' Network unreachable
     *  X'04' Host unreachable
     *  X'05' Connection refused
     *  X'06' TTL expired
     *  X'07' Command not supported
     *  X'08' Address type not supported
     *  X'09' to X'FF' unassigned
     * RSV     RESERVED
     * ATYP   address type of following address
     *  IP V4 address: X'01'
     *  DOMAINNAME: X'03'
     *  IP V6 address: X'04'
     * BND.ADDR server bound address
     * BND.PORT server bound port in network octet order
     */
    | AddressNegotiationResponseFrame(Byte, Byte, Byte, Byte, Array<Byte>, Int16)
}