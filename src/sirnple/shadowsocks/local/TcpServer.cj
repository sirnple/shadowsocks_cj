package sirnple.shadowsocks.local

import sirnple.shadowsocks.config.LOG_CONFIG

public class TcpServer {
    private static let log = SimpleLogger(TypeInfo.of<TcpServer>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private let config = ShadowsocksConfig.readConfig()
    private let cryptor = PasswordCryptor(config.password, config.method)
    public TcpServer() {}
    public func start() {
        try(serverSocket = TcpServerSocket(bindAt: SocketAddress(config.local, config.localPort))) {
            serverSocket.bind()
            log.debug("TcpServer started: listening at ${serverSocket.localAddress.toString()}")

            while(true) {
                let client = serverSocket.accept()
                log.debug("TcpServer accepted a connection from ${client.remoteAddress.toString()}, bind at ${client.localAddress.toString()}")
                TcpHandler(config, client, cryptor).handle()
            }

        }
    }
}