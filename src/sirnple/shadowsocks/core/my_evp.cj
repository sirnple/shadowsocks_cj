package shadowsocks_cj.sirnple.shadowsocks.core

import crypto4cj.symmetrycj.*

public let EVP_PADDING_NO: Int32 = 0
public let EVP_PADDING_PKCS7: Int32 = 1
public let EVP_PADDING_ISO7816_4: Int32 = 2
public let EVP_PADDING_ANSI923: Int32 = 3
public let EVP_PADDING_ISO10126: Int32 = 4
public let EVP_PADDING_ZERO: Int32 = 5

public class EVP {
    var evp: UInt64 = 0
    var enbuf: Array<UInt8>
    var enoutLen: Int32 = 0
    var deoutLen: Int32 = 0
    var debuf: Array<UInt8>
    
    public init(){
        let e: UInt64 = unsafe { EVP_CIPHER_CTX_new() }
        this.evp = e
        this.enoutLen = 0
        this.deoutLen = 0
        this.enbuf = Array<UInt8>()
        this.debuf = Array<UInt8>()
    }
    func free() {
        unsafe { EVP_CIPHER_CTX_free(this.evp) }
    }

    public func encryptInit(cipher: CIPHER, key: Array<UInt8>, iv: Array<UInt8>): Unit {
        let k: CPointerHandle<UInt8> = unsafe { acquireArrayRawData(key) }
        let i: CPointerHandle<UInt8> = unsafe { acquireArrayRawData(iv) }
        let ret: Int32 = unsafe { EVP_EncryptInit(this.evp, cipher.getCipher(), k.pointer, i.pointer) }
        if(ret != 1) {
            throw CryptoException("encrypt init error")
        }
        unsafe {
            releaseArrayRawData(k)
            releaseArrayRawData(i)
        }
    }

    public func setPadding(pad: Int32): Unit {
        let ret: Int32 = unsafe { EVP_CIPHER_CTX_set_padding(this.evp, pad) }
        if(ret != 1) {
            throw CryptoException("Set Padding error")
        }
    }

    public func encryptUpdate(input: Array<UInt8>): Array<Byte> {
        let len: Int64 = ((input.size >> 4 ) + 1) << 4
        let i: CPointerHandle<UInt8> = unsafe { acquireArrayRawData(input) }
        this.enbuf = Array<UInt8>(len, item: 0)
        let o: CPointerHandle<UInt8> = unsafe { acquireArrayRawData(this.enbuf) }
        let l: Int32 = 0
        let ptr = unsafe { malloc(4) }
        let outl = unsafe {CPointer<Int32>(ptr)}
        unsafe { outl.write(l)}
        let ret: Int32 = unsafe { EVP_EncryptUpdate(this.evp, o.pointer, outl, i.pointer, Int32(input.size)) }
        if(ret != 1) {
            throw CryptoException("encrypt update error")
        }
        this.enoutLen = unsafe { outl.read()}
        var res: ArrayList<UInt8> = ArrayList<UInt8>(Int64(this.enoutLen))
        for(i in 0..Int64(this.enoutLen)) {
            let item = unsafe { o.pointer.read(i) }
            res.append(item)
        }
        unsafe {
            releaseArrayRawData(i) 
            releaseArrayRawData(o)
            free(outl)
        }
        res.toArray()
    }

    public func decryptInit(cipher: CIPHER, key: Array<UInt8>, iv: Array<UInt8>): Unit {
        let k: CPointerHandle<UInt8> = unsafe { acquireArrayRawData(key) }
        let i: CPointerHandle<UInt8> = unsafe { acquireArrayRawData(iv) }
        let ret: Int32 = unsafe { EVP_DecryptInit(this.evp, cipher.getCipher(), k.pointer, i.pointer) }
        if(ret != 1) {
            throw CryptoException("decrypt init error")
        }
        unsafe {
            releaseArrayRawData(k)
            releaseArrayRawData(i)
        }
    }

    public func decryptUpdate(input: Array<UInt8>): Array<Byte> {
        let len: Int64 = input.size
        let i: CPointerHandle<UInt8> = unsafe { acquireArrayRawData(input) }
        this.debuf = Array<UInt8>(len, item: 0)
        let o: CPointerHandle<UInt8> = unsafe { acquireArrayRawData(this.debuf) }
        let l: Int32 = 0
        let ptr = unsafe { malloc(4) }
        let outl = unsafe {CPointer<Int32>(ptr)}
        unsafe { outl.write(l)}
        let ret: Int32 = unsafe { EVP_DecryptUpdate(this.evp, o.pointer, outl, i.pointer, Int32(input.size)) }
        if(ret != 1) {
            throw CryptoException("decrypt update error")
        }
        this.deoutLen = unsafe { outl.read()}
        var res: ArrayList<UInt8> = ArrayList<UInt8>(Int64(this.deoutLen))
        for(i in 0..Int64(this.deoutLen)) {
            let item = unsafe { o.pointer.read(i) }
            res.append(item)
        }
        unsafe {
            releaseArrayRawData(i) 
            releaseArrayRawData(o)
            free(outl)
        }
        res.toArray()
    }
}