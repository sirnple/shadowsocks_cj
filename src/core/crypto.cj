package shadowsocks_cj.core

import shadowsocks_cj.util.assert
import shadowsocks_cj.config.{LOG_CONFIG, SUPPORT_METHOD}
import std.collection.{ArrayList, HashMap}
import std.convert.Parsable
import std.random.Random
import std.reflect.TypeInfo
import std.core.min
import std.console.Console
import std.crypto.cipher.BlockCipher
import std.crypto.digest.digest
import std.env.getStdOut
import stdx.logger.SimpleLogger
import stdx.crypto.digest.MD5
import stdx.crypto.crypto.{SM4, OperationMode}


/**
 * 遵循Shadowsocks协议的加密器
 * 一个转发的handler（如TcpHandler）转发的所有数据都应该使用同一个加密器
 *
 * @author sirnple
 */
public interface ShadowsocksCryptor {
    func encrypt(data: Array<Byte>): Array<Byte>
    func decrypt(data: Array<Byte>): Array<Byte>
}

public const IV_LEN = 16 // 目前约定iv的值为16字节，在发送的packet就可以不带iv.len了

public class PasswordCryptor <: ShadowsocksCryptor {
    private let log = SimpleLogger(getStdOut())
    private let algorithm: String
    private let keyLenInBits: Int32
    private let encryptMode: String
    private let myKey: Array<Byte>
    private var myEncryptEvp: ?SM4 = None
    private var myDecryptEvp: ?SM4 = None
    private var myEncryptIv: ?Array<Byte> = None
    private var myDecryptIv: ?Array<Byte> = None

    public PasswordCryptor(private let password: String, private let method: String) {
        algorithm = method.split("-")[0]
        keyLenInBits = Int32.parse(method.split("-")[1])
        encryptMode = method.split("-")[2]
        myKey = deriveMd5Key(keyLenInBits, password)
        log.level= LOG_CONFIG.logLevel
    }

    public func encrypt(data: Array<Byte>): Array<Byte> {
        match (myEncryptEvp) {
            case None =>  // 首次加密
                let iv = genIv(UInt8(IV_LEN))
                let sm4 = initEncrypt(iv)
                return iv + sm4.encrypt(data)
            case Some(evp) =>  // 后续加密
                return evp.encrypt(data)
        }
    }
    
    public func decrypt(data: Array<Byte>): Array<Byte> {
        match (myDecryptEvp) {
            case None =>  // 首次解密
                match (tryUnpackFirstEncryptedPacket(data)) {
                    case Some((iv, encryptedPayload)) =>
                        let sm4 = initDecrypt(iv)
                        return sm4.decrypt(encryptedPayload)
                    case None => throw Exception("Invalid first packet")
                }
            case Some(evp) =>  // 后续解密
                return evp.decrypt(data)
        }
    }

    private func genIv(ivLen: UInt8): Array<Byte> {
        Random().nextBytes(Int32(ivLen))
    }

    private func initEncrypt(iv: Array<Byte>): SM4 {
        match ((algorithm, encryptMode, keyLenInBits)) {
            case ("sm4", "cfb", 128) => 
                let sm4 = SM4(OperationMode.CFB, myKey, iv: iv)
                myEncryptEvp = Some(sm4)
                myEncryptIv = Some(iv)
                return sm4
            case ("sm4", "gcm", 128) =>
                let sm4 = SM4(OperationMode.GCM, myKey, iv: iv)
                myEncryptEvp = Some(sm4)
                myEncryptIv = Some(iv)
                return sm4
            case _ => throw Exception("Not support method: ${algorithm}-${keyLenInBits}-${encryptMode}, support(case insensitive): ${String.join(SUPPORT_METHOD, delimiter: ", ")}")
        }
    }

    private func initDecrypt(iv: Array<Byte>): SM4 {
        match ((algorithm, encryptMode, keyLenInBits)) {
            case ("sm4", "cfb", 128) =>
                let sm4 = SM4(OperationMode.CFB, myKey, iv: iv)
                myDecryptEvp = Some(sm4)
                myDecryptIv = Some(iv)
                return sm4
            case ("sm4", "gcm", 128) =>
                let sm4 = SM4(OperationMode.GCM, myKey, iv: iv)
                myDecryptEvp = Some(sm4)
                myDecryptIv = Some(iv)
                return sm4
            case _ => throw Exception("Not support method: ${encryptMode}, support(case insensitive): ${String.join(SUPPORT_METHOD, delimiter: ", ")}")
        }
    }
}

/* 
 * MD5密钥派生算法，这里和shadowsocks 4.1.2的实现保持一致
 */
public func deriveMd5Key(keyLenInBits: Int32, password: String): Array<Byte> {
    let keyLenInBytes = Int64(keyLenInBits/8)
    let key = Array<Byte>(keyLenInBytes, repeat: 0)
    let md5digest = MD5()
    let MD5_DIGEST_LENGTH = md5digest.size
    let intermediate = Array<Byte>(password.size + MD5_DIGEST_LENGTH, repeat: 0)
    var i = 0
    let md5sum = Array<Byte>(MD5_DIGEST_LENGTH, repeat: 0)
    let passwordArray = password.toArray()
    while (i < keyLenInBytes) {
        if (i==0) {
            digest(md5digest, passwordArray).copyTo(md5sum, 0, 0, MD5_DIGEST_LENGTH)
        } else {
            md5sum.copyTo(intermediate, 0, 0, MD5_DIGEST_LENGTH)
            passwordArray.copyTo(intermediate, 0, MD5_DIGEST_LENGTH, password.size)
            digest(md5digest, intermediate).copyTo(md5sum, 0, 0, MD5_DIGEST_LENGTH)
        }
        md5sum.copyTo(key, 0, i, min(MD5_DIGEST_LENGTH, keyLenInBytes - i))
        i += MD5_DIGEST_LENGTH
    }
    return key
}
