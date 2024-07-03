package sirnple.shadowsocks.core

from std import unittest.*
from std import unittest.testmacro.*


@Test
class PasswordCryptorTest {
    @TestCase
    func test_encrypt_and_decrypt_with_diff_cryptor_which_has_same_password_and_method() {
        let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
        let randomData = Random().nextUInt8s(Array<Byte>(16, item: 0))
        let (iv, encryptedData) = cryptor1.encryptWithNewIv(randomData)

        let cryptor2 = PasswordCryptor("password", "aes-256-cfb")
        @Assert(randomData == cryptor2.decryptWithGivenIv(data: encryptedData, iv: iv))
    }

    @TestCase
    func test_encrypt_and_decrypt_by_diff_cryptor_which_has_diff_password() {
        let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
        let randomData = Random().nextUInt8s(Array<Byte>(16, item: 0))
        let (iv, encryptedData) = cryptor1.encryptWithNewIv(randomData)

        let cryptor2 = PasswordCryptor("password2", "aes-256-cfb")
        @Assert(randomData != cryptor2.decryptWithGivenIv(data: encryptedData, iv: iv))
    }

    @TestCase
    func test_encrypt_by_aesCfb128() {
        let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
        let iv: Array<Byte> = [157, 92, 193, 3, 150, 59, 186, 102, 232, 205, 165, 108, 83, 220, 116, 168]
        let encrypted = cryptor1.encryptWithGivenIv(data: [ 1, 10, 10, 10, 10, 31, 144, 71, 69, 84, 32], iv: iv)
        @Assert(encrypted == [212, 237, 20, 94, 3, 153, 230, 255, 57, 217, 187])
    }
}

@Test
func test_deriveMd5Key() {
    let key = deriveMd5Key(256, "password")
    @Assert(key == [95, 77, 204, 59, 90, 167, 101, 214, 29, 131, 39, 222, 184, 130, 207, 153, 43, 149, 153, 10, 145, 81, 55, 74, 189, 143, 248, 197, 167, 160, 254, 8])
}