package shadowsocks_cj.core.crypto

import std.unittest.testmacro.*
import std.collection.forEach

@Test
func testOpenSSL() {
    unsafe {
        let cipherName = LibC.mallocCString("aes-128-cfb")
        println("Cipher name: ${cipherName}")
        let cipher = EVP_get_cipherbyname(cipherName)

        let ctx = EVP_CIPHER_CTX_new()
        let out = CPointer<Byte>()
        let outl = CPointer<Int32>()
        let `in` = CPointer<Byte>()
        var `inl` = 0
        // EVP_CipherUpdate是通用接口，EVP_EncryptUpdate/EVP_DecryptUpdate是专用接口
        // 这里保持原样作为基础测试
        EVP_CipherUpdate(ctx, out, outl, `in`, 0)

        // 测试释放上下文
        EVP_CIPHER_CTX_free(ctx)
        LibC.free(cipherName)
    }
}

@Test
func testAES256CFBStreaming() {
    // 测试数据
    let plaintext: Array<Byte> = [
        0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 
        0x61, 0x20, 0x74, 0x65, 0x73, 0x74, 0x21, 0x21
    ]
    let plaintextPrt = unsafe { acquireArrayRawData(plaintext).pointer }
    
    // 32字节密钥
    let key: Array<Byte> = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
        0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
    ]
    let keyPtr = unsafe { acquireArrayRawData(key).pointer }
    
    // 16字节IV
    let iv: Array<Byte> = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
    ]
    let ivPtr = unsafe { acquireArrayRawData(iv).pointer }

    // 初始化加密上下文
    let cipherName = unsafe { LibC.mallocCString("aes-256-cfb") }
    let cipher = unsafe { EVP_get_cipherbyname(cipherName) }
    let encryptCtx = unsafe { EVP_CIPHER_CTX_new() }
    unsafe { EVP_EncryptInit_ex(encryptCtx, cipher, CPointer<UInt8>(), keyPtr, ivPtr) }

    // 流式加密（分3次处理）
    var encrypted = unsafe { acquireArrayRawData(Array<Byte>()) }
    let chunkSize = unsafe { acquireArrayRawData(Int32(plaintext.size / 3)) }
    var offset = 0i32
    
    // 第一次加密
    var outBuf = unsafe { acquireArrayRawData (Array<Byte>(Int64(chunkSize.pointer.read()) + 16, repeat: 0))}
    var outLen = unsafe { acquireArrayRawData (0i32) }
    unsafe { 
        EVP_EncryptUpdate(encryptCtx, outBuf.pointer, outLen.pointer, plaintextPrt + Int64(offset), chunkSize.pointer)
        for (i in 0..outLen.pointer.read()) {
            encrypted.array.concat([outBuf.pointer.read(Int64(i))])
        }
        offset += chunkSize.pointer.read()
    }

    // 第二次加密
    unsafe { 
        EVP_EncryptUpdate(encryptCtx, outBuf.pointer, outLen.pointer, plaintextPrt + Int64(offset), chunkSize.pointer)
        for (i in 0..outLen.pointer.read()) {
            encrypted.array.concat([outBuf.pointer.read(Int64(i))])
        }
        offset += chunkSize.pointer.read()
    }

    // 第三次加密（剩余部分）
    unsafe {
        EVP_EncryptUpdate(encryptCtx, outBuf.pointer, outLen.pointer,
                            plaintextPrt + Int64(offset), acquireArrayRawData(Int32(plaintext.size - Int64(offset))).pointer)
        for (i in 0..outLen.pointer.read()) {
            encrypted.array.concat([outBuf.pointer.read(Int64(i))])
        }
    }

    // 最终处理
    unsafe { 
        EVP_EncryptFinal_ex(encryptCtx, outBuf.pointer, outLen.pointer)

        for (i in 0..outLen.pointer.read()) {
            encrypted.array.concat([outBuf.pointer.read(Int64(i))])
        }
    }

    // 初始化解密上下文
    let decryptCtx = unsafe { EVP_CIPHER_CTX_new() }
    unsafe { EVP_DecryptInit_ex(decryptCtx, cipher, CPointer<Byte>(), keyPtr, ivPtr) }
    
    // 流式解密（分2次处理）
    var decrypted = unsafe { acquireArrayRawData(Array<Byte>()) }
    
    // 第一次解密
    unsafe {
        EVP_DecryptUpdate(decryptCtx, outBuf.pointer, outLen.pointer,
                            encrypted.pointer, acquireArrayRawData(Int32(encrypted.array.size / 2)).pointer)
        for (i in 0..outLen.pointer.read()) {
            decrypted.array.concat([outBuf.pointer.read(Int64(i))])
        }
    }

    // 第二次解密（剩余部分）
    unsafe {
        EVP_DecryptUpdate(decryptCtx, outBuf.pointer, outLen.pointer,
                            encrypted.pointer + Int64(encrypted.array.size / 2), 
                            acquireArrayRawData(Int32(encrypted.array.size - encrypted.array.size / 2)).pointer)
        for (i in 0..outLen.pointer.read()) {
            decrypted.array.concat([outBuf.pointer.read(Int64(i))])
        }
    }

    // 最终处理
    unsafe {
        EVP_DecryptFinal_ex(decryptCtx, outBuf.pointer, outLen.pointer)
        for (i in 0..outLen.pointer.read()) {
            decrypted.array.concat([outBuf.pointer.read(Int64(i))])
        }
    }

    // 验证解密结果
    @Assert(decrypted.array == plaintext)

    // 清理资源
    unsafe { 
        EVP_CIPHER_CTX_free(encryptCtx)
        EVP_CIPHER_CTX_free(decryptCtx)
        LibC.free(cipherName)
    }
}
