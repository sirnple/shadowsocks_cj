package shadowsocks_cj.sirnple.shadowsocks.core

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.{forEach, ArrayList}
import shadowsocks_cj.sirnple.shadowsocks.config.SUPPORT_METHOD
import std.random.Random


@Test
class PasswordCryptorTest {
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
        let firstPlainData = Random().nextUInt8s(Array<Byte>(100, repeat: 0))
        let followPlainData = Random().nextUInt8s(Array<Byte>(100, repeat: 0))
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
            let firstPlainData = Random().nextUInt8s(Array<Byte>(100, repeat: 0))
            let followPlainData = Random().nextUInt8s(Array<Byte>(100, repeat: 0))
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
            records.add(future)
        }
        records |> forEach { r => r.get() }
    }
}

@Test
func test_deriveMd5Key() {
    let key = deriveMd5Key(256, "password")
    @Assert(key == [95, 77, 204, 59, 90, 167, 101, 214, 29, 131, 39, 222, 184, 130, 207, 153, 43, 149, 153, 10, 145, 81, 55, 74, 189, 143, 248, 197, 167, 160, 254, 8])
}