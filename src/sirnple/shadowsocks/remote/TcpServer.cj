package sirnple.shadowsocks.remote

import sirnple.shadowsocks.config.{ShadowsocksConfig, LOG_CONFIG}
import sirnple.shadowsocks.core.PasswordCryptor

from std import log.*
from std import reflect.*
from std import console.Console
from std import socket.*

public class TcpServer {
    private static let log = SimpleLogger(TypeInfo.of<TcpServer>().qualifiedName, LOG_CONFIG.logLevel, Console.stdOut)
    private let config = ShadowsocksConfig.readConfig()

    public func start() {
        try(serverSocket = TcpServerSocket(bindAt: SocketAddress(config.server, config.serverPort))) {
            serverSocket.bind()
            log.debug("TcpServer started: listening at ${serverSocket.localAddress.toString()}")

            while (true) {
                let client = serverSocket.accept()
                log.debug("TcpServer accepted a connection from ${client.remoteAddress.toString()}, bind at ${client.localAddress.toString()}")
                TcpHandler(config, client, PasswordCryptor(config.password, config.method)).handle()
            }
        }
    }
}