package sirnple.shadowsocks.local

enum Status {
    | Init
    | AuthRequest   // 客户端发送认证方式的请求
    | AuthResponse  // 本地服务器端发送认证方式的响应
    | AddressNegotiationRequest // 客户端发送协商地址的请求
    | AddressNegotiationResponse    // 本地服务器端发送协商地址的响应
    | Connected         // 上行和下行连接都建立，可以进行数据传输
    | Disconnected      // 上行和下行连接都关闭，可以回收资源
    | Destory           // 回收资源
}