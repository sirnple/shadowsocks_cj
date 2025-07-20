package shadowsocks_cj.core.crypto

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
import shadowsocks_cj.core.{ArrayExt, tryUnpackFirstEncryptedPacket, IV_LEN}

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

public class PasswordCryptor <: ShadowsocksCryptor {
    private let log = SimpleLogger(getStdOut())
    private let algorithm: String
    private let keyLenInBits: Int32
    private let encryptMode: String
    private let myKey: Array<Byte>
    private var myEncryptEvp: ?SM4 = None
    private var myDecryptEvp: ?SM4 = None
    private var myEncryptCtx: CPointer<EVP_CIPHER_CTX> = CPointer()
    private var myEncryptCipher: CPointer<EVP_CIPHER> = CPointer()
    private var myDecryptCtx: CPointer<EVP_CIPHER_CTX> = CPointer()
    private var myDecryptCipher: CPointer<EVP_CIPHER> = CPointer()
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
        match {
            case myEncryptCtx.isNull() && myEncryptCipher.isNull() => 
                initEncrypt()
                let out = unsafe {acquireArrayRawData(Array<Byte>(data.size, repeat: 0))}
                let outl = unsafe {acquireArrayRawData(0i32)}
                let rcode = unsafe {EVP_EncryptUpdate(myEncryptCtx, out.pointer, outl.pointer, acquireArrayRawData(data).pointer, Int32(data.size))}
                if (rcode != OPENSSL_SUCCESS) {
                    log.error("Encrypt failed, return code: ${rcode}, error: ${getOpenSSLError()}")
                    throw Exception("Encrypt failed, return code: ${rcode}")
                }
                if (out.array.size != Int64(outl.array[0])) {
                    throw Exception("Encrypt failed, out.size != outl, out size: ${out.array.size}, outl: ${outl.array[0]}")
                }
                unsafe { 
                    releaseArrayRawData(outl)
                    releaseArrayRawData(out)
                }
                return (myEncryptIv ?? throw Exception("'myEncryptIv' not initialized")) + out.array
            case !myEncryptCtx.isNull() && !myEncryptCipher.isNull() =>
                let out = unsafe {acquireArrayRawData(Array<Byte>(data.size, repeat: 0))}
                let outl = unsafe {acquireArrayRawData(0i32)}
                let rcode = unsafe {EVP_EncryptUpdate(myEncryptCtx, out.pointer, outl.pointer, acquireArrayRawData(data).pointer, Int32(data.size))}
                if (rcode != OPENSSL_SUCCESS) {
                    log.error("Encrypt failed, return code: ${rcode}, error: ${getOpenSSLError()}")
                    throw Exception("Encrypt failed, return code: ${rcode}")
                }
                if (out.array.size != Int64(outl.array[0])) {
                    throw Exception("Encrypt failed, out.size != outl, out size: ${out.array.size}, outl: ${outl.array[0]}")
                }
                let r = out.array
                unsafe { 
                    releaseArrayRawData(outl)
                    releaseArrayRawData(out)
                }
                return r
            case _ => throw Exception("Encryption not initialized correctly, you should make 'myEncryptCtx' and 'myEncryptCipher' initialized first")
        }
    }
    
    public func decrypt(data: Array<Byte>): Array<Byte> {
        match {
            case myDecryptCtx.isNull() && myDecryptCipher.isNull() =>
                match (tryUnpackFirstEncryptedPacket(data)) {
                    case Some((iv, cipherText)) => 
                        initDecrypt(iv)
                        let out = unsafe {acquireArrayRawData(Array<Byte>(cipherText.size, repeat: 0))}
                        let outl = unsafe {acquireArrayRawData(0i32)}
                        let rcode = unsafe {EVP_DecryptUpdate(myDecryptCtx, out.pointer, outl.pointer, acquireArrayRawData(cipherText).pointer, Int32(cipherText.size))}
                        if (rcode != OPENSSL_SUCCESS) {
                            log.error("Decrypt failed, return code: ${rcode}, error: ${getOpenSSLError()}")
                            throw Exception("Decrypt failed, return code: ${rcode}")
                        }
                        if (out.array.size != Int64(outl.array[0])) {
                            throw Exception("Decrypt failed, out.size != outl, out size: ${out.array.size}, outl: ${outl.array[0]}")
                        }
                        unsafe { 
                            releaseArrayRawData(outl)
                            releaseArrayRawData(out)
                        }
                        return out.array
                    case None => throw Exception("Decrypt failed, argument 'data' is not valid packet start with iv which length is ${IV_LEN}")
                }
            case !myDecryptCtx.isNull() && !myDecryptCipher.isNull() =>
                let out = unsafe {acquireArrayRawData(Array<Byte>(data.size, repeat: 0))}
                let outl = unsafe {acquireArrayRawData(0i32)}
                let rcode = unsafe {EVP_DecryptUpdate(myDecryptCtx, out.pointer, outl.pointer, acquireArrayRawData(data).pointer, Int32(data.size))}
                if (rcode != OPENSSL_SUCCESS) {
                    log.error("Decrypt failed, return code: ${rcode}, error: ${getOpenSSLError()}")
                    throw Exception("Decrypt failed, return code: ${rcode}")
                }
                if (out.array.size != Int64(outl.array[0])) {
                    throw Exception("Decrypt failed, out.size != outl, out size: ${out.array.size}, outl: ${outl.array[0]}")
                }
                unsafe { 
                    releaseArrayRawData(outl)
                    releaseArrayRawData(out)
                }
                return out.array
            case _ => throw Exception("Decryption not initialized correctly, you should make 'myDecryptCtx' and 'myDecryptCipher' initialized first")
        }
    }

    private func genIv(ivLen: UInt8): Array<Byte> {
        Random().nextBytes(Int32(ivLen))
    }

    private func initEncrypt(): Unit {
        let iv = genIv(UInt8(IV_LEN))
        let cipher = unsafe {EVP_get_cipherbyname(LibC.mallocCString(method))}
        if (cipher.isNull()) {
            throw Exception("Not supported method: ${method}")
        }
        let ctx = unsafe {EVP_CIPHER_CTX_new()}
        if (ctx.isNull()) {
            throw Exception("Init encrypt failed!")
        }
        let rcode = unsafe {EVP_EncryptInit_ex(ctx, cipher, CPointer(), acquireArrayRawData(myKey).pointer, acquireArrayRawData(iv).pointer)}
        if (rcode != OPENSSL_SUCCESS) {
            throw Exception("Init encrypt failed, return code: ${rcode}")
        }
        this.myEncryptCipher = cipher
        this.myEncryptCtx = ctx
        this.myEncryptIv = iv
    }

    private func initDecrypt(iv: Array<Byte>): Unit {
        if (iv.size != IV_LEN) {
            throw Exception("Invalid IV length: ${iv.size}")
        }
        let cipher = unsafe {EVP_get_cipherbyname(LibC.mallocCString(method))}
        if (cipher.isNull()) {
            throw Exception("Not supported method: ${method}")
        }
        let ctx = unsafe {EVP_CIPHER_CTX_new()}
        if (ctx.isNull()) {
            throw Exception("Init encrypt failed!")
        }
        let rcode = unsafe {EVP_DecryptInit_ex(ctx, cipher, CPointer(), acquireArrayRawData(myKey).pointer, acquireArrayRawData(iv).pointer)}
        if (rcode != OPENSSL_SUCCESS) {
            throw Exception("Init encrypt failed, return code: ${rcode}")
        }
        this.myDecryptCipher = cipher
        this.myDecryptCtx = ctx
        this.myDecryptIv = iv
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
