package sirnple.shadowsocks.core

import sirnple.shadowsocks.util.assert
import sirnple.shadowsocks.config.LOG_CONFIG
from crypto4cj import pbkdf2cj.*
from crypto4cj import md5cj.*
from crypto4cj import aescj.*
from crypto4cj import utils.*
from std import collection.{ArrayList, HashMap}
from std import convert.Parsable
from std import random.Random
from std import reflect.TypeInfo
from std import math.min


/**
 * 遵循Shadowsocks协议的加密器
 * 一个转发的handler（如TcpHandler）转发的所有数据都应该使用同一个加密器
 *
 * @author sirnple
 */
public interface ShadowsocksCryptor {
    func encryptFirst(data: Array<Byte>): Array<Byte>
    func encryptFollow(data: Array<Byte>): Array<Byte>
    func decryptFirst(data: Array<Byte>): Array<Byte>
    func decryptFollow(data: Array<Byte>): Array<Byte>
}

public const IV_LEN = 16 // 目前约定iv的值为16字节，在发送的packet就可以不带iv.len了
public class PasswordCryptor <: ShadowsocksCryptor {
    private let log = SimpleLogger(TypeInfo.of<PasswordCryptor>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private let algorithm: String
    private let keyLenInBits: Int32
    private let encryptMode: String
    private let myKey: Array<Byte>
    private let myEncryptEvp = EVP()
    private let myDecryptEvp = EVP()
    private var myEncryptIv: ?Array<Byte> = None
    private var myDecryptIv: ?Array<Byte> = None

    public PasswordCryptor(private let password: String, private let method: String) {
        algorithm = method.split("-")[0]
        assert(algorithm.toAsciiLower() == "aes", message: "Only support algorithm: aes")
        keyLenInBits = Int32.parse(method.split("-")[1])
        assert(keyLenInBits == 128 || keyLenInBits == 192 || keyLenInBits == 256, message: "Only support keyLen: 128/192/256")
        encryptMode = method.split("-")[2]
        // 目前只支持cfb，因为cfb可以不用分组，实现比较简单
        assert(encryptMode.toAsciiLower() == "cfb", message: "Only support encryptMode: cbc")
        myKey = deriveMd5Key(keyLenInBits, password)
    }

    public func encryptFirst(data: Array<Byte>): Array<Byte> {
        match (myEncryptIv) {
            case None =>
                let tmpIv = genIv(UInt8(IV_LEN))
                myEncryptIv = Some(tmpIv)
                initEncrypt(tmpIv)
                let cipher = myEncryptEvp.encryptUpdate(data)
                log.debug("First encrypt\niv: ${tmpIv}\nplainData: ${data}\ncipherData: ${cipher}")
                tmpIv + cipher
            case Some(_) =>
                throw Exception("Already encrypt first")
        }
    }

    public func encryptFollow(data: Array<Byte>): Array<Byte> {
        match (myEncryptIv) {
            case None =>
                throw Exception("Please call encryptFirst first")
            case Some(encryptIv) =>
                myEncryptEvp.encryptUpdate(data)
        }
    }

    public func decryptFirst(data: Array<Byte>): Array<Byte> {
        match (tryUnpackFirstEncryptedPacket(data)) {
            case Some((iv, encryptedPayload)) =>
                myDecryptIv = Some(iv)
                initDecrypt(iv)
                let decrypted = myDecryptEvp.decryptUpdate(encryptedPayload)
                log.debug("First decrypt\niv: ${iv}\nplainData: ${decrypted}\ncipherData: ${encryptedPayload}")
                decrypted
            case None =>
                throw Exception("Not a valid first packet")
        }
    }

    public func decryptFollow(data: Array<Byte>): Array<Byte> {
        match (myDecryptIv) {
            case None =>
                throw Exception("Please call decryptFirst first")
            case Some(decryptIv) =>
                myDecryptEvp.decryptUpdate(data)
        }
    }

    ~init() {
        myEncryptEvp.free()
        myDecryptEvp.free()
    }

    private func genIv(ivLen: UInt8): Array<Byte> {
        Random().nextUInt8s(Array<Byte>(Int64(ivLen), item: 0))
    }

    private func initEncrypt(iv: Array<Byte>) {
        match ((algorithm, encryptMode, keyLenInBits)) {
            case ("aes", "cfb", 256) => 
                myEncryptEvp.encryptInit(AES.aes256Cfb128, myKey, iv)
                myEncryptEvp.setPadding(EVP_PADDING_NO)
            case _ => throw Exception("Not support encryptMode: ${encryptMode}, only support cfb")
        }
    }

    private func initDecrypt(iv: Array<Byte>) {
        match ((algorithm, encryptMode, keyLenInBits)) {
            case ("aes", "cfb", 256) =>
                myDecryptEvp.decryptInit(AES.aes256Cfb128, myKey, iv)
                myDecryptEvp.setPadding(EVP_PADDING_NO)
            case _ => throw Exception("Not support encryptMode: ${encryptMode}, only support cfb")
        }
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