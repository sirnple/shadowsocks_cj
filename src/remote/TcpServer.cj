package shadowsocks_cj.remote

import shadowsocks_cj.config.{ShadowsocksConfig, LOG_CONFIG}
import shadowsocks_cj.core.PasswordCryptor

import logger.SimpleLogger
import std.reflect.*
import std.console.Console
import std.net.*

public class TcpServer {
    private static let log = SimpleLogger(Console.stdOut)
    private let config = ShadowsocksConfig.readConfig()
    static init() {
        log.level = LOG_CONFIG.logLevel
    }

    public func start() {
        try(serverSocket = TcpServerSocket(bindAt: IPSocketAddress(config.server, config.serverPort))) {
            serverSocket.bind()
            log.info("TcpServer started: listening at ${serverSocket.localAddress.toString()}")

            while (true) {
                let client = serverSocket.accept()
                log.info("TcpServer accepted a connection from ${client.remoteAddress.toString()}, bind at ${client.localAddress.toString()}")
                TcpHandler(config, client).handle()
            }
        }
    }
}