package sirnple.shadowsocks.core

from crypto4cj import pbkdf2cj.*

public class PasswordCryptor <: Cryptor {
    public PasswordCryptor(private let password: String, private let method: String) {}

    public func encrypt(iv: Array<Byte>, data: Array<Byte>): Array<Byte> {
        return data
    }

    public func decrypt(iv: Array<Byte>, data: Array<Byte>): Array<Byte> {
        return data
    }

    public func genIv(ivLen: Byte): Array<Byte> {
        return Array<Byte>(Int64(ivLen), item: 0)
    }

    private func generateKey(): Array<Byte> {
        return pbkdf2HmacSha1(password.toArray(), b"salt", 1000, 256)
    }
}