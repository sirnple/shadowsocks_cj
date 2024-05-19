package sirnple.shadowsocks.remote

import sirnple.shadowsocks.core.Cryptor

class TcpHandler {
    public TcpHandler(let config: Config, let clientSock: TcpSocket, let cryptor: Cryptor) {}
    
    public func handle() {
        while (true) {
            let buf = Array<Byte>(4096, item: 0)
            let readCount = clientSock.read(buf)
            if (readCount != 0) {
            } else {
                break
            }
        }
    }


}