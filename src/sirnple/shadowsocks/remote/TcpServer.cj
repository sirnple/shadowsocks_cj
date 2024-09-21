package shadowsocks_cj.sirnple.shadowsocks.remote

import shadowsocks_cj.sirnple.shadowsocks.config.{ShadowsocksConfig, LOG_CONFIG}
import shadowsocks_cj.sirnple.shadowsocks.core.PasswordCryptor

import std.log.*
import std.reflect.*
import std.console.Console
import std.net.*

public class TcpServer {
    private static let log = SimpleLogger(TypeInfo.of<TcpServer>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private let config = ShadowsocksConfig.readConfig()

    public func start() {
        try(serverSocket = TcpServerSocket(bindAt: IPSocketAddress(config.server, config.serverPort))) {
            serverSocket.bind()
            log.debug("TcpServer started: listening at ${serverSocket.localAddress.toString()}")

            while (true) {
                let client = serverSocket.accept()
                log.debug("TcpServer accepted a connection from ${client.remoteAddress.toString()}, bind at ${client.localAddress.toString()}")
                TcpHandler(config, client).handle()
            }
        }
    }
}