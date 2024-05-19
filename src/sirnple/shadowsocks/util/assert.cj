package sirnple.shadowsocks.util

public func assert(condition: Bool, message!: String = "") {
    if (!condition) {
        throw Exception(message)
    }
}