package shadowsocks_cj.core.crypto

@C
public struct EVP_CIPHER {
}
@C
public struct EVP_CIPHER_CTX {
}

foreign func EVP_get_cipherbyname(name: CString): CPointer<EVP_CIPHER>
foreign func EVP_CIPHER_CTX_new(): CPointer<EVP_CIPHER_CTX>
foreign func EVP_CipherUpdate(ctx: CPointer<EVP_CIPHER_CTX>, out: CPointer<Byte>, outl: CPointer<Int32>, `in`: CPointer<Byte>, inl: Int32): Int32
foreign func EVP_CIPHER_CTX_free(ctx: CPointer<EVP_CIPHER_CTX>): Unit
foreign func EVP_EncryptInit_ex(ctx: CPointer<EVP_CIPHER_CTX>, cipher: CPointer<EVP_CIPHER>, 
                              impl: CPointer<Byte>, key: CPointer<Byte>, iv: CPointer<Byte>): Int32
foreign func EVP_DecryptInit_ex(ctx: CPointer<EVP_CIPHER_CTX>, cipher: CPointer<EVP_CIPHER>,
                              impl: CPointer<Byte>, key: CPointer<Byte>, iv: CPointer<Byte>): Int32
foreign func EVP_EncryptUpdate(ctx: CPointer<EVP_CIPHER_CTX>, out: CPointer<Byte>, outl: CPointer<Int32>, `in`: CPointer<Byte>, inl: CPointer<Int32>): Int32
foreign func EVP_DecryptUpdate(ctx: CPointer<EVP_CIPHER_CTX>, out: CPointer<Byte>, outl: CPointer<Int32>, `in`: CPointer<Byte>, inl: CPointer<Int32>): Int32
foreign func EVP_EncryptFinal_ex(ctx: CPointer<EVP_CIPHER_CTX>, out: CPointer<Byte>, outl: CPointer<Int32>): Int32
foreign func EVP_DecryptFinal_ex(ctx: CPointer<EVP_CIPHER_CTX>, out: CPointer<Byte>, outl: CPointer<Int32>): Int32
foreign func EVP_CIPHER_CTX_set_padding(ctx: CPointer<EVP_CIPHER_CTX>, pad: Int32): Int32