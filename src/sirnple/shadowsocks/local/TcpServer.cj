package shadowsocks_cj.sirnple.shadowsocks.local

import shadowsocks_cj.sirnple.shadowsocks.config.{ShadowsocksConfig, LOG_CONFIG}
import std.log.SimpleLogger
import std.reflect.TypeInfo
import std.socket.{TcpServerSocket, SocketAddress}
import std.console.Console

public class TcpServer {
    private static let log = SimpleLogger(TypeInfo.of<TcpServer>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private let config = ShadowsocksConfig.readConfig()
    public TcpServer() {}
    public func start() {
        try(serverSocket = TcpServerSocket(bindAt: SocketAddress(config.local, config.localPort))) {
            serverSocket.bind()
            log.debug("TcpServer started: listening at ${serverSocket.localAddress.toString()}")

            while(true) {
                let client = serverSocket.accept()
                log.debug("TcpServer accepted a connection from ${client.remoteAddress.toString()}, bind at ${client.localAddress.toString()}")
                TcpHandler(config, client).handle()
            }

        }
    }
}