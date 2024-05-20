package sirnple.shadowsocks.remote

enum Status {
    | Init
    | Connected
    | RelayUpwardFinished
    | RelayDownwardFinished
    | Disconnected
    | Destory
}