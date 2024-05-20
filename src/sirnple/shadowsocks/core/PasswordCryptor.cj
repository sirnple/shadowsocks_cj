package sirnple.shadowsocks.core

import sirnple.shadowsocks.util.assert
from crypto4cj import pbkdf2cj.*
from crypto4cj import aescj.*
from crypto4cj import utils.*
from std import collection.ArrayList
from std import convert.Parsable
from std import random.Random

public class PasswordCryptor <: Cryptor {
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
        assert(encryptMode.toAsciiLower() == "cbc", message: "Only support encryptMode: cbc")
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
        return Array<Byte>(Int64(ivLen), item: 0)
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
        return Random().nextUInt8s(Array<Byte>(16, item: 0))
    }

    private func aesEncrypt(data: Array<UInt8>): (Array<Byte>, Array<UInt8>) {
        var key = AESKEY()
        var outside: Array<UInt8> = Array<UInt8>(Int64(AES_BLOCK_SIZE), item: 0)
        var keyRet = aesSetEncryptKey(generateKey(), keyLen, key)
        var groupedData: ArrayList<Array<UInt8>> = zeroPadding(data)
        var res: ArrayList<UInt8> = ArrayList<UInt8>()
        let iv = genIv(UInt8(AES_BLOCK_SIZE))
        match (encryptMode) {
            case "cbc" =>
                for( i in 0..groupedData.size ) {
                    aesCbcEncrypt(groupedData[i], outside, key, iv, AES_ENCRYPT)
                    res.appendAll(outside)
                }   
            case _ => throw Exception("Not support encryptMode: ${encryptMode}, only support cbc")
        }
        log.debug("aesEncrypt iv: ${iv}")
        return (iv, res.toArray())
    }

    private func zeroPadding(data: Array<UInt8>): ArrayList<Array<Byte>> {
        return arrayTo2Array(data, Int64(AES_BLOCK_SIZE))
    }

    private func aesDecrypt(iv: Array<UInt8>, data: Array<UInt8>): Array<UInt8> {
        log.debug("aesDecrypt iv: ${iv}")
        var key = AESKEY()
        var outside: Array<UInt8> = Array<UInt8>(Int64(AES_BLOCK_SIZE), item: 0)
        var keyRet = aesSetDecryptKey(generateKey(), keyLen, key)
        var groupedData: ArrayList<Array<UInt8>> = zeroPadding(data)
        var res: ArrayList<UInt8> = ArrayList<UInt8>()
        match (encryptMode) {
            case "cbc" =>
                for( i in 0..groupedData.size ) {
                    aesCbcEncrypt(groupedData[i], outside, key, iv, AES_DECRYPT)
                    res.appendAll(outside)
                }   
            case _ => throw Exception("Not support encryptMode: ${encryptMode}, only support cbc")
        }
        return res.toArray()
    }
}