package sirnple.shadowsocks.local

public class TcpServer {
    private static let log = SimpleLogger(TypeInfo.of<TcpServer>().qualifiedName, ALL, Console.stdOut)
    private let config = Config.readConfig()
    public TcpServer() {}
    public func start() {
        try(serverSocket = TcpServerSocket(bindAt: SocketAddress(config.local, config.localPort))) {
            serverSocket.bind()
            log.debug("TcpServer started: listening at ${serverSocket.localAddress.toString()}")

            while(true) {
                try(client = serverSocket.accept()) {
                    log.debug("TcpServer accepted a connection from ${client.remoteAddress.toString()}, bind at ${client.localAddress.toString()}")
                    TcpHandler(config, client).handle()
                }
            }

        }
    }
}