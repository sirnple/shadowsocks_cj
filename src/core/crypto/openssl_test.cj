package shadowsocks_cj.core.crypto

import std.unittest.testmacro.*

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
        EVP_CipherUpdate(ctx, out, outl, `in`, 0)

        // 测试释放上下文
        EVP_CIPHER_CTX_free(ctx)
        LibC.free(cipherName)
    }
}