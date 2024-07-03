package sirnple.shadowsocks.core

import sirnple.shadowsocks.util.assert
import sirnple.shadowsocks.config.LOG_CONFIG
from crypto4cj import pbkdf2cj.*
from crypto4cj import md5cj.*
from crypto4cj import aescj.*
from crypto4cj import utils.*
from std import collection.ArrayList
from std import convert.Parsable
from std import random.Random
from std import reflect.TypeInfo
from std import math.min

public interface Cryptor {
    func encryptWithNewIv(data: Array<Byte>): (iv: Array<Byte>, encryptedData: Array<Byte>)
    func encryptWithGivenIv(data!: Array<Byte>, iv!: Array<Byte>): Array<Byte>
    func decryptWithGivenIv(data!: Array<Byte>, iv!: Array<Byte>): Array<Byte>
}

public let IV_LEN = Int64(AES_BLOCK_SIZE)
public class PasswordCryptor <: Cryptor {
    private let log = SimpleLogger(TypeInfo.of<PasswordCryptor>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private let algorithm: String
    private let keyLenInBits: Int32
    private let encryptMode: String
    private var myKey: Option<Array<Byte>> = None

    public PasswordCryptor(private let password: String, private let method: String) {
        algorithm = method.split("-")[0]
        assert(algorithm.toAsciiLower() == "aes", message: "Only support algorithm: aes")
        keyLenInBits = Int32.parse(method.split("-")[1])
        assert(keyLenInBits == 128 || keyLenInBits == 192 || keyLenInBits == 256, message: "Only support keyLen: 128/192/256")
        encryptMode = method.split("-")[2]
        // 目前只支持cfb，因为cfb可以不用分组，实现比较简单
        assert(encryptMode.toAsciiLower() == "cfb", message: "Only support encryptMode: cbc")
    }

    public func encryptWithNewIv(data: Array<Byte>): (iv: Array<Byte>, encryptedData: Array<Byte>) {
        let iv = genIv(UInt8(IV_LEN))
        return (iv, encryptWithGivenIv(data: data, iv: iv))
    }

    public func encryptWithGivenIv(data!: Array<Byte>, iv!: Array<Byte>): Array<Byte> {
        return match (algorithm) {
            case "aes" => return aesEncrypt(data, iv)
            case _ => throw Exception("Not support algorithm: ${algorithm}, only support aes")
        }
    }

    public func decryptWithGivenIv(data!: Array<Byte>, iv!: Array<Byte>): Array<Byte> {
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
                // let key = pbkdf2HmacSha1(password.toArray(), randomSalt(), 1000, keyLen)
                let key = deriveMd5Key(keyLenInBits, password)
                myKey = key
                return key
        }
    }

    private func randomSalt(): Array<Byte> {
        return [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10] // 暂时使用固定盐值，省去local和remote的密钥协商
        // return Random().nextUInt8s(Array<Byte>(16, item: 0))
    }

    private func aesEncrypt(data: Array<UInt8>, iv: Array<UInt8>): Array<UInt8> {
        var key = AESKEY()
        var outside: Array<UInt8> = Array<UInt8>(data.size, item: 0)
        aesSetEncryptKey(generateKey(), keyLenInBits, key)
        match (encryptMode) {
            case "cfb" =>
                aesCfb128Encrypt(data, outside, key, iv.clone(), AES_ENCRYPT)
            case _ => throw Exception("Not support encryptMode: ${encryptMode}, only support cfb")
        }
        return outside
    }

    private func aesDecrypt(iv: Array<UInt8>, data: Array<UInt8>): Array<UInt8> {
        var key = AESKEY()
        var outside: Array<UInt8> = Array<UInt8>(data.size, item: 0)
        let genKey = generateKey()
        aesSetEncryptKey(genKey, keyLenInBits, key)
        match (encryptMode) {
            case "cfb" =>
                aesCfb128Encrypt(data, outside, key, iv.clone(), AES_DECRYPT)
            case _ => throw Exception("Not support encryptMode: ${encryptMode}, only support cfb")
        }
        return outside
    }
}

/* 
 * MD5密钥派生算法，这里和shadowsocks 4.1.2的实现保持一致
 */
public func deriveMd5Key(keyLenInBits: Int32, password: String): Array<Byte> {
    let keyLenInBytes = Int64(keyLenInBits/8)
    let key = Array<Byte>(keyLenInBytes, item: 0)
    let intermediate = Array<Byte>(password.size + MD5_DIGEST_LENGTH, item: 0)
    var i = 0
    let md5sum = Array<Byte>(MD5_DIGEST_LENGTH, item: 0)
    let passwordArray = password.toArray()
    while (i < keyLenInBytes) {
        if (i==0) {
            md5(passwordArray, md5sum)
        } else {
            md5sum.copyTo(intermediate, 0, 0, MD5_DIGEST_LENGTH)
            passwordArray.copyTo(intermediate, 0, MD5_DIGEST_LENGTH, password.size)
            md5(intermediate, md5sum)
        }
        md5sum.copyTo(key, 0, i, min(MD5_DIGEST_LENGTH, keyLenInBytes - i))
        i += MD5_DIGEST_LENGTH
    }
    return key
}