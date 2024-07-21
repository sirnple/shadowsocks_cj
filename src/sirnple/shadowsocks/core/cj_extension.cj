package shadowsocks_cj.sirnple.shadowsocks.core

import std.collection.{filter, collectArray, collectArrayList}

extend Array<Byte> <: ArrayExt {
    public operator func +(arr: Array<Byte>): Array<Byte> {
        let a = Array<Byte>(this.size + arr.size, item: 0)
        this.copyTo(a, 0, 0, this.size)
        arr.copyTo(a, 0, this.size, arr.size)
        return a
    }

    public func intersection(arr: Array<Byte>): Array<Byte> {
        return this |> filter { x: Byte => arr.contains(x) } |> collectArray
    }
}

public interface ArrayExt {
    operator func +(arr: Array<Byte>): Array<Byte>
    func intersection(arr: Array<Byte>): Array<Byte>
}