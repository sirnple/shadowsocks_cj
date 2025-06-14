package shadowsocks_cj.local

enum Status {
    | Init  // 初始化
    | Auth   // 认证
    | Negotiating // 地址协商中
    | Established // 建立已连接
    | Transerring // 数据传输中
    | Closing // 关闭连接
}
