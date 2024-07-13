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
        let iv: Array<Byte> = [125, 140, 240, 179, 211, 160, 170, 0, 215, 231, 121, 140, 233, 26, 50, 251]
        let encrypted = cryptor1.encryptWithGivenIv(data: [3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187], iv: iv)
        @Assert(encrypted == [215, 23, 103, 149, 62, 255, 199, 192, 152, 87, 51, 152, 59, 27, 71, 183, 26])
    }

    @TestCase
    func test_decrypt_byaesCfb128() {
        let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
        let iv: Array<Byte> = [125, 140, 240, 179, 211, 160, 170, 0, 215, 231, 121, 140, 233, 26, 50, 251]
        let decrypted = cryptor1.decryptWithGivenIv(data: [215, 23, 103, 149, 62, 255, 199, 192, 152, 87, 51, 152, 59, 27, 71, 183, 26], iv: iv)
        @Assert(decrypted == [3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187])
    }
}

@Test
func test_deriveMd5Key() {
    let key = deriveMd5Key(256, "password")
    @Assert(key == [95, 77, 204, 59, 90, 167, 101, 214, 29, 131, 39, 222, 184, 130, 207, 153, 43, 149, 153, 10, 145, 81, 55, 74, 189, 143, 248, 197, 167, 160, 254, 8])
}