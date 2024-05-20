import sirnple.shadowsocks.local.TcpServer as Local
import sirnple.shadowsocks.remote.TcpServer as Remote

main(): Int64 {
    let local = spawn {
        Local().start()
    }
    let remote = spawn {
        Remote().start()
    }
    local.get()
    remote.get()
    return 0
}