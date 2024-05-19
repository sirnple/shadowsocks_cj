package sirnple.shadowsocks.local

struct DstAddr {
    public DstAddr(public let atyp: Byte, public let addr: Array<Byte>, public let port: Array<Byte>) {

    }

    public func toBytes(): Array<Byte> {
        return [atyp] + addr + port
    }
}