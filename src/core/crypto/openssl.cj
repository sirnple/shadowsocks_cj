package shadowsocks_cj.core.crypto

@C
struct EVP_CIPHER {
}
@C
struct EVP_CIPHER_CTX {
}

foreign func EVP_get_cipherbyname(name: CString): CPointer<EVP_CIPHER>

foreign func EVP_CIPHER_CTX_new(): CPointer<EVP_CIPHER_CTX>

foreign func EVP_CipherUpdate(ctx: CPointer<EVP_CIPHER_CTX>, out: CPointer<Byte>, outl: CPointer<Int32>, `in`: CPointer<Byte>, inl: Int32): Int32

foreign func EVP_CIPHER_CTX_free(ctx: CPointer<EVP_CIPHER_CTX>): Unit

public func myf() {
    unsafe {
        let cipherName = LibC.mallocCString("aes-128-cfb")
        println("Cipher name: ${cipherName}")
        let cipher = EVP_get_cipherbyname(cipherName)

        let ctx = EVP_CIPHER_CTX_new()
        let out = CPointer<Byte>()
        let outl = CPointer<Int32>()
        let `in` = CPointer<Byte>()
        var `inl` = 0
        EVP_CipherUpdate(ctx, out, outl, `in`, 0)

        // 测试释放上下文
        EVP_CIPHER_CTX_free(ctx)
        LibC.free(cipherName)
    }
}