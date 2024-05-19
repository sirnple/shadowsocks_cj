package sirnple.shadowsocks.core

// from crypto4cj import aescj.*

public interface Cryptor {
    func encrypt(data: Array<Byte>): (Array<Byte>, Array<Byte>)
    func decrypt(iv: Array<Byte>, data: Array<Byte>): Array<Byte>
}