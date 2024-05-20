package sirnple.shadowsocks.core

extend Array<T> where T <: Byte {
    operator func +(arr: Array<Byte>): Array<Byte> {
        let a = Array<Byte>(this.size + arr.size, item: 0)
        for(i in 0..this.size) {
            a[i] = this[i]
        }
        for(i in 0..arr.size) {
            a[i+this.size] = arr[i]
        }
        return a
    }
}