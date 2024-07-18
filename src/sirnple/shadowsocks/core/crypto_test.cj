package sirnple.shadowsocks.core

from std import unittest.*
from std import unittest.testmacro.*
from crypto4cj import symmetrycj.*


@Test
class PasswordCryptorTest {
    // @TestCase
    // func test_encrypt_and_decrypt_with_diff_cryptor_which_has_same_password_and_method() {
    //     let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
    //     let randomData = Random().nextUInt8s(Array<Byte>(16, item: 0))
    //     let encrypted = cryptor1.encryptFirst(randomData)

    //     let cryptor2 = PasswordCryptor("password", "aes-256-cfb")
    //     @Assert(randomData == cryptor2.decryptFirst(data: encrypted))
    // }

    // @TestCase
    // func test_encrypt_and_decrypt_by_diff_cryptor_which_has_diff_password() {
    //     let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
    //     let randomData = Random().nextUInt8s(Array<Byte>(16, item: 0))
    //     let encryptedData = cryptor1.encryptFirst(randomData)

    //     let cryptor2 = PasswordCryptor("password2", "aes-256-cfb")
    //     @Assert(randomData != cryptor2.decryptFirst(data: encryptedData))
    // }

    // @TestCase
    // func test_encrypt_by_aesCfb128() {
    //     let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
        // let iv: Array<Byte> = [125, 140, 240, 179, 211, 160, 170, 0, 215, 231, 121, 140, 233, 26, 50, 251]
        // let encrypted = cryptor1.encryptFollow(data: [3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187], iv: iv)
        // @Assert(encrypted == [215, 23, 103, 149, 62, 255, 199, 192, 152, 87, 51, 152, 59, 27, 71, 183, 26])
        // let encrypted1 = cryptor1.encryptFollow(data: [3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187], iv: iv)
        // @Assert(encrypted1 == [215, 23, 103, 149, 62, 255, 199, 192, 152, 87, 51, 152, 59, 27, 71, 183, 26])
    // }

    // @TestCase
    // func test_decrypt_byaesCfb128() {
    //     let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
        // let iv: Array<Byte> = [125, 140, 240, 179, 211, 160, 170, 0, 215, 231, 121, 140, 233, 26, 50, 251]
        // let decrypted = cryptor1.decryptFirst(data: [215, 23, 103, 149, 62, 255, 199, 192, 152, 87, 51, 152, 59, 27, 71, 183, 26], iv: iv)
        // @Assert(decrypted == [3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187])
    // }

    @TestCase
    func test_evp() {
        let iv: Array<Byte> = [150, 9, 234, 125, 153, 63, 171, 9, 80, 30, 250, 172, 68, 194, 54, 128]
        let key: Array<Byte> = [71, 69, 84, 32, 47, 32, 72, 84, 84, 80, 47, 49, 46, 49, 13, 10, 72, 111, 115, 116, 58, 32, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46]
        let evp = EVP()
        let evp1 = EVP()
        evp.encryptInit(AES.aes256Cfb128, key, iv)
        evp.setPadding(EVP_PADDING_NO)
        let encrypted = evp.encryptUpdate([3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187])
        evp1.decryptInit(AES.aes256Cfb128, key, iv)
        evp1.setPadding(EVP_PADDING_NO)
        let decrypted = evp1.decryptUpdate(encrypted)
        @Assert(decrypted == [3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187])

        let iv1: Array<Byte> = [125, 140, 240, 179, 211, 160, 170, 0, 215, 231, 121, 140, 233, 26, 50, 251]
        evp1.encryptInit(AES.aes256Cfb128, key, iv1)
        evp1.setPadding(EVP_PADDING_NO)
        let encrypted1 = evp1.encryptUpdate([3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187])

        evp.decryptInit(AES.aes256Cfb128, key, iv1)
        evp.setPadding(EVP_PADDING_NO)
        let decrypted1 = evp.decryptUpdate(encrypted1)
        @Assert(decrypted1 == [3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187])

        evp.encryptInit(AES.aes256Cfb128, key, iv)
        let encrypted2 = evp.encryptUpdate([3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187])
        evp1.decryptInit(AES.aes256Cfb128, key, iv)
        let decrypted2 = evp1.decryptUpdate(encrypted2)
        @Assert(decrypted2 == [3, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 1, 187])
    }

    @TestCase[firstPlainData in random<Array<Byte>>(), followPlainData in random<Array<Byte>>(), anotherFollowPlainData in random<Array<Byte>>()]
    func test_ss_cryptor(firstPlainData: Array<Byte>, followPlainData: Array<Byte>, anotherFollowPlainData: Array<Byte>) {
        let cryptor = PasswordCryptor("password", "aes-256-cfb")
        let encrypted = cryptor.encryptFirst(firstPlainData)
        let encryptedFollow = cryptor.encryptFollow(followPlainData)
        let encryptedFollowAnother = cryptor.encryptFollow(anotherFollowPlainData)
        let decrypted = cryptor.decryptFirst(encrypted)
        let decryptedFollow = cryptor.decryptFollow(encryptedFollow)
        let decryptedFollowAnother = cryptor.decryptFollow(encryptedFollowAnother)
        @Assert(decrypted == firstPlainData)
        @Assert(decryptedFollow == followPlainData)
        @Assert(decryptedFollowAnother == anotherFollowPlainData)
    }

    @TestCase
    func test_ss_cryptor_1() {
        let cryptor = PasswordCryptor("password", "aes-256-cfb")
        let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
        let firstPlainData: Array<Byte> = [22, 3, 1, 2, 0, 1, 0, 1, 252, 3, 3, 222, 217, 175, 184, 195, 128, 154, 103, 132, 132, 77, 91, 52, 93, 73, 1, 246, 113, 60, 107, 163, 157, 114, 129, 156, 197, 125, 145, 90, 2, 87, 175, 32, 4, 14, 185, 119, 56, 184, 220, 99, 185, 18, 117, 235, 152, 177, 234, 91, 165, 180, 246, 215, 19, 78, 76, 136, 151, 187, 250, 220, 68, 108, 43, 225, 0, 62, 19, 2, 19, 3, 19, 1, 192, 44, 192, 48, 0, 159, 204, 169, 204, 168, 204, 170, 192, 43, 192, 47, 0, 158, 192, 36, 192, 40, 0, 107, 192, 35, 192, 39, 0, 103, 192, 10, 192, 20, 0, 57, 192, 9, 192, 19, 0, 51, 0, 157, 0, 156, 0, 61, 0, 60, 0, 53, 0, 47, 0, 255, 1, 0, 1, 117, 0, 0, 0, 18, 0, 16, 0, 0, 13, 119, 119, 119, 46, 98, 97, 105, 100, 117, 46, 99, 111, 109, 0, 11, 0, 4, 3, 0, 1, 2, 0, 10, 0, 22, 0, 20, 0, 29, 0, 23, 0, 30, 0, 25, 0, 24, 1, 0, 1, 1, 1, 2, 1, 3, 1, 4, 51, 116, 0, 0, 0, 16, 0, 14, 0, 12, 2, 104, 50, 8, 104, 116, 116, 112, 47, 49, 46, 49, 0, 22, 0, 0, 0, 23, 0, 0, 0, 49, 0, 0, 0, 13, 0, 42, 0, 40, 4, 3, 5, 3, 6, 3, 8, 7, 8, 8, 8, 9, 8, 10, 8, 11, 8, 4, 8, 5, 8, 6, 4, 1, 5, 1, 6, 1, 3, 3, 3, 1, 3, 2, 4, 2, 5, 2, 6, 2, 0, 43, 0, 5, 4, 3, 4, 3, 3, 0, 45, 0, 2, 1, 1, 0, 51, 0, 38, 0, 36, 0, 29, 0, 32, 146, 149, 157, 17, 53, 193, 195, 180, 10, 47, 239, 178, 56, 11, 243, 33, 90, 176, 172, 18, 96, 52, 249, 147, 253, 143, 8, 33, 156, 140, 68, 70, 0, 21, 0, 176, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let followPlainData: Array<Byte> = [22, 3, 3, 0, 70, 16, 0, 0, 66, 65, 4, 19, 248, 32, 102, 4, 113, 218, 209, 154, 6, 40, 53, 132, 203, 49, 201, 98, 160, 81, 74, 9, 198, 172, 192, 62, 24, 224, 218, 46, 220, 26, 42, 71, 52, 26, 235, 138, 165, 152, 215, 249, 92, 120, 51, 211, 75, 41, 80, 10, 230, 110, 110, 119, 243, 203, 120, 101, 127, 206, 146, 46, 238, 18, 126, 20, 3, 3, 0, 1, 1, 22, 3, 3, 0, 40, 178, 36, 183, 81, 58, 31, 12, 217, 204, 91, 4, 11, 82, 22, 129, 170, 74, 236, 83, 115, 168, 71, 46, 210, 176, 151, 234, 207, 32, 225, 137, 49, 103, 204, 153, 125, 213, 154, 199, 52]
        let encrypted = cryptor.encryptFirst(firstPlainData)
        let decrypted = cryptor1.decryptFirst(encrypted)
        let encrypted1 = cryptor1.encryptFirst(firstPlainData)
        let decrypted1 = cryptor.decryptFirst(encrypted1)

        let encryptedFollow = cryptor.encryptFollow(followPlainData)
        let decryptedFollow = cryptor1.decryptFollow(encryptedFollow)
        @Assert(decrypted == firstPlainData)
        @Assert(decryptedFollow == followPlainData)
    }
}

@Test
func test_deriveMd5Key() {
    let key = deriveMd5Key(256, "password")
    @Assert(key == [95, 77, 204, 59, 90, 167, 101, 214, 29, 131, 39, 222, 184, 130, 207, 153, 43, 149, 153, 10, 145, 81, 55, 74, 189, 143, 248, 197, 167, 160, 254, 8])
}