package sirnple.shadowsocks.core


public enum ShadowSocksFrame {

    /*
     * ShadowSocks协议:
     * +------+----------+----------+----------+
     * | ATYP | DST.ADDR | DST.PORT |   DATA   |
     * +------+----------+----------+----------+
     * |  1   | Variable |    2     | Variable |
     * +------+----------+----------+----------+
     * ATYP     地址类型，0x01表示IPv4，0x03表示域名，0x04表示IPv6，1字节
     * DST.ADDR 目标地址，IPv4地址4字节，IPv6地址16字节
     * DST.PORT 目标端口，2字节
     * DATA     数据，长度不定
     */
    | RawFrame(Byte, Array<Byte>, UInt16, Array<Byte>)
    /* 
     * ShadowSocks加密数据
     * +----------+----------+------------------+
     * |  IV.LEN  |    IV    |  ENCRYPTED_DATA  |
     * +----------+----------+------------------+
     * |    1     | Variable |     Variable     |
     * +----------+----------+------------------+
     * IV.LEN    IV的长度，1字节
     * IV        初始化向量，IV.LEN字节
     * ENCRYPTED_DATA 加密后的数据，也即是RawFrame加密后的数据，因为采取定长加密，长度为RawFrame的长度
     */
    | EncryptedFrame(Byte, Array<Byte>, Array<Byte>)
}