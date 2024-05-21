import sirnple.shadowsocks.local.TcpServer as Local
import sirnple.shadowsocks.remote.TcpServer as Remote
from crypto4cj import aescj.*
from crypto4cj import utils.*
from std import collection.*
from encoding import hex.*
from std import socket.*

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