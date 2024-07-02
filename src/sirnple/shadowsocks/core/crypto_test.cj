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
}

@Test
func test_deriveMd5Key() {
    let key = deriveMd5Key(256, "password")
    @Assert(key == [95, 77, 204, 59, 90, 167, 101, 214, 29, 131, 39, 222, 184, 130, 207, 153, 43, 149, 153, 10, 145, 81, 55, 74, 189, 143, 248, 197, 167, 160, 254, 8])
}