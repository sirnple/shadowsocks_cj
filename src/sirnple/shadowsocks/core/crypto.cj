package sirnple.shadowsocks.core

import sirnple.shadowsocks.util.assert
import sirnple.shadowsocks.config.LOG_CONFIG
from crypto4cj import pbkdf2cj.*
from crypto4cj import aescj.*
from crypto4cj import utils.*
from std import collection.ArrayList
from std import convert.Parsable
from std import random.Random
from std import reflect.TypeInfo

public interface Cryptor {
    func encrypt(data: Array<Byte>): (Array<Byte>, Array<Byte>)
    func decrypt(iv: Array<Byte>, data: Array<Byte>): Array<Byte>
}

public let IV_LEN = Int64(AES_BLOCK_SIZE)
public class PasswordCryptor <: Cryptor {
    private let log = SimpleLogger(TypeInfo.of<PasswordCryptor>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private let algorithm: String
    private let keyLen: Int32
    private let encryptMode: String
    private var myKey: Option<Array<Byte>> = None

    public PasswordCryptor(private let password: String, private let method: String) {
        algorithm = method.split("-")[0]
        assert(algorithm.toAsciiLower() == "aes", message: "Only support algorithm: aes")
        keyLen = Int32.parse(method.split("-")[1])
        assert(keyLen == 128 || keyLen == 192 || keyLen == 256, message: "Only support keyLen: 128/192/256")
        encryptMode = method.split("-")[2]
        // 目前只支持cfb，因为cfb可以不用分组，实现比较简单
        assert(encryptMode.toAsciiLower() == "cfb", message: "Only support encryptMode: cbc")
    }

    public func encrypt(data: Array<Byte>): (Array<Byte>, Array<Byte>) {
        return match (algorithm) {
            case "aes" => return aesEncrypt(data)
            case _ => throw Exception("Not support algorithm: ${algorithm}, only support aes")
        }
    }

    public func decrypt(iv: Array<Byte>, data: Array<Byte>): Array<Byte> {
        return match (algorithm) {
            case "aes" => return aesDecrypt(iv, data)
            case _ => throw Exception("Not support algorithm: ${algorithm}, only support aes")
        }
    }

    private func genIv(ivLen: UInt8): Array<Byte> {
        Random().nextUInt8s(Array<Byte>(Int64(ivLen), item: 0))
    }

    private func generateKey(): Array<Byte> {
        return match (myKey) {
            case Some(key) => key
            case None =>
                let key = pbkdf2HmacSha1(password.toArray(), randomSalt(), 1000, keyLen)
                myKey = key
                return key
        }
    }

    private func randomSalt(): Array<Byte> {
        return [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10] // 暂时使用固定盐值，省去local和remote的密钥协商
        // return Random().nextUInt8s(Array<Byte>(16, item: 0))
    }

    private func aesEncrypt(data: Array<UInt8>): (Array<Byte>, Array<UInt8>) {
        var key = AESKEY()
        var outside: Array<UInt8> = Array<UInt8>(data.size, item: 0)
        aesSetEncryptKey(generateKey(), keyLen, key)
        let iv = genIv(UInt8(IV_LEN))
        match (encryptMode) {
            case "cfb" =>
                aesCfb8Encrypt(data, outside, key, iv.clone(), AES_ENCRYPT)
            case _ => throw Exception("Not support encryptMode: ${encryptMode}, only support cfb")
        }
        return (iv, outside)
    }

    private func aesDecrypt(iv: Array<UInt8>, data: Array<UInt8>): Array<UInt8> {
        var key = AESKEY()
        var outside: Array<UInt8> = Array<UInt8>(data.size, item: 0)
        aesSetEncryptKey(generateKey(), keyLen, key)
        match (encryptMode) {
            case "cfb" =>
                aesCfb8Encrypt(data, outside, key, iv.clone(), AES_DECRYPT)
            case _ => throw Exception("Not support encryptMode: ${encryptMode}, only support cfb")
        }
        return outside
    }
}