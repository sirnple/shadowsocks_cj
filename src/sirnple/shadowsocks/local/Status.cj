package sirnple.shadowsocks.local

enum Status {
    | Init
    | AuthRequest
    | AuthResponse
    | AddressNegotiationRequest
    | AddressNegotiationResponse
    | Connected         // 上行和下行转发都通
    | RelayUpwardFinished // 上行转发数据完成
    | RelayDownwardFinished      // 下行转发数据完成
    | Disconnected      // 本地应用和远端SS服务都关闭
    | Destory           // 回收资源
}