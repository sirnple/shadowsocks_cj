package shadowsocks_cj.sirnple.shadowsocks.local

import shadowsocks_cj.sirnple.shadowsocks.config.{ShadowsocksConfig, LOG_CONFIG}
import logger.SimpleLogger
import std.reflect.TypeInfo
import std.net.{TcpServerSocket, IPSocketAddress}
import std.console.Console

public class TcpServer {
    private static let log = SimpleLogger(Console.stdOut)
    private let config = ShadowsocksConfig.readConfig()
    public TcpServer() {
        log.level = LOG_CONFIG.logLevel
    }
    public func start() {
        try(serverSocket = TcpServerSocket(bindAt: IPSocketAddress(config.local, config.localPort))) {
            serverSocket.bind()
            log.info("TcpServer started: listening at ${serverSocket.localAddress.toString()}")

            while(true) {
                let client = serverSocket.accept()
                log.info("TcpServer accepted a connection from ${client.remoteAddress.toString()}, bind at ${client.localAddress.toString()}")
                TcpHandler(config, client).handle()
            }

        }
    }
}