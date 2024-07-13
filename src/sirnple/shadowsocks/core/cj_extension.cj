package sirnple.shadowsocks.core

from std import collection.{filter, collectArray, collectArrayList}

extend Array<T> <: ArrayExt<T> where T <: Byte & Equatable<T> {
    public operator func +(arr: Array<T>): Array<T> {
        let a = Array<T>(this.size + arr.size, item: 0)
        this.copyTo(a, 0, 0, this.size)
        arr.copyTo(a, 0, this.size, arr.size)
        return a
    }

    public func intersection(arr: Array<T>): Array<T> {
        return this |> filter { x: T => arr.contains(x) } |> collectArray
    }
}

public interface ArrayExt<T> {
    operator func +(arr: Array<T>): Array<T>
    func intersection(arr: Array<T>): Array<T>
}