package shadowsocks_cj.sirnple.shadowsocks.core

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.{forEach, ArrayList}
import crypto4cj.symmetrycj.*
import shadowsocks_cj.sirnple.shadowsocks.config.SUPPORT_METHOD
import std.random.Random


@Test
class PasswordCryptorTest {
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

    @TestCase[firstPlainData in random<Array<Byte>>(), followPlainData in random<Array<Byte>>()]
    func test_ss_cryptor(firstPlainData: Array<Byte>, followPlainData: Array<Byte>) {
        let cryptor = PasswordCryptor("password", "aes-256-cfb")
        let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
        let encrypted = cryptor.encryptFirst(firstPlainData)
        let decrypted = cryptor1.decryptFirst(encrypted)
        let encrypted1 = cryptor1.encryptFirst(firstPlainData)
        let decrypted1 = cryptor.decryptFirst(encrypted1)

        let encryptedFollow = cryptor.encryptFollow(followPlainData)
        let decryptedFollow = cryptor1.decryptFollow(encryptedFollow)
        @Assert(decrypted == firstPlainData)
        @Assert(decryptedFollow == followPlainData)
    }

    @TestCase[method in SUPPORT_METHOD]
    func test_ss_cryptor_with_diff_method(method: String) {
        let cryptor = PasswordCryptor("password", method)
        let cryptor1 = PasswordCryptor("password", method)
        let firstPlainData = Random().nextUInt8s(Array<Byte>(100, item: 0))
        let followPlainData = Random().nextUInt8s(Array<Byte>(100, item: 0))
        let encrypted = cryptor.encryptFirst(firstPlainData)
        let decrypted = cryptor1.decryptFirst(encrypted)
        let encrypted1 = cryptor1.encryptFirst(firstPlainData)
        let decrypted1 = cryptor.decryptFirst(encrypted1)

        let encryptedFollow = cryptor.encryptFollow(followPlainData)
        let decryptedFollow = cryptor1.decryptFollow(encryptedFollow)
        @Assert(decrypted == firstPlainData)
        @Assert(decryptedFollow == followPlainData)
    }

    @TestCase
    func test_ss_cryptor_many_times() {
        for (i in 0..100) {
            let cryptor = PasswordCryptor("password", "aes-256-cfb")
            let cryptor1 = PasswordCryptor("password", "aes-256-cfb")
            let firstPlainData = Random().nextUInt8s(Array<Byte>(100, item: 0))
            let followPlainData = Random().nextUInt8s(Array<Byte>(100, item: 0))
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

    @TestCase
    func test_ss_cryptor_with_multi_thread() {
        let records = ArrayList<Future<Unit>>()
        for (t in 0..100) {
            let future = spawn {
                test_ss_cryptor_many_times()
            }
            records.append(future)
        }
        records |> forEach { r => r.get() }
    }
}

@Test
func test_deriveMd5Key() {
    let key = deriveMd5Key(256, "password")
    @Assert(key == [95, 77, 204, 59, 90, 167, 101, 214, 29, 131, 39, 222, 184, 130, 207, 153, 43, 149, 153, 10, 145, 81, 55, 74, 189, 143, 248, 197, 167, 160, 254, 8])
}