package sirnple.shadowsocks.core

extend Array<T> <: ArrayExt where T <: Byte {
    public operator func +(arr: Array<Byte>): Array<Byte> {
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

public interface ArrayExt {
    operator func +(arr: Array<Byte>): Array<Byte>
}