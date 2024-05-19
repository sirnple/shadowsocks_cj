package sirnple.shadowsocks.core

// from crypto4cj import aescj.*

public interface Cryptor {
    func encrypt(iv: Array<Byte>, data: Array<Byte>): Array<Byte>
    func decrypt(iv: Array<Byte>, data: Array<Byte>): Array<Byte>
    func genIv(ivLen: Byte): Array<Byte>
}

// func aesEncode(inside: Array<UInt8>, keys: Array<UInt8>): Array<UInt8> {
//     var key = AESKEY()
//     var outside: Array<UInt8> = Array<UInt8>(Int64(AES_BLOCK_SIZE), item: 0)
//     var keyRet = aesSetEncryptKey(keys, 128, key)
//     var data: ArrayList<Array<UInt8>> = arrayTo2Array(inside, Int64(AES_BLOCK_SIZE))
//     var res: ArrayList<UInt8> = ArrayList<UInt8>()
//     for( i in 0..data.size ) {
//         aesEncrypt(data[i], outside, key)
//         res.appendAll(outside)
//     }   
//     return res.toArray()
// }

// func aesDecode(inside: Array<UInt8>, keys: Array<UInt8>): Array<UInt8> {
//     var key = AESKEY()
//     var outside: Array<UInt8> = Array<UInt8>(Int64(AES_BLOCK_SIZE), item: 0)
//     var keyRet = aesSetDecryptKey(keys, 128, key)
//     var data: ArrayList<Array<UInt8>> = arrayTo2Array(inside, Int64(AES_BLOCK_SIZE))
//     var res: ArrayList<UInt8> = ArrayList<UInt8>()
//     for( i in 0..data.size ) {
//         aesDecrypt(data[i], outside, key)
//         res.appendAll(outside)
//     }   
//     return res.toArray()
// }