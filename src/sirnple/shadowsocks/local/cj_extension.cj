package sirnple.shadowsocks.local

public func assert(condition: Bool, message!: String = "") {
    if (!condition) {
        throw Exception(message)
    }
}

public func toPort(high!: Byte, low!: Byte): UInt16 {
    return UInt16(high) << 8 | UInt16(low)
}

extend Array<T> where T <: Byte {
    operator func +(arr: Array<Byte>): Array<Byte> {
        let a = Array<Byte>(this.size + arr.size, item: 0)
        for(i in 0..this.size) {
            a[i] = this[i]
        }
        for(i in this.size..a.size) {
            a[i] = arr[i]
        }
        return a
    }
}