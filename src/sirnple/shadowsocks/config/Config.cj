package sirnple.shadowsocks.config

from encoding import json.stream.*
from std import fs.*
from std import io.*

public struct Config <: JsonDeserializable<Config> & ToString {
    public Config(
        public let server: String,
        public let serverPort: UInt16,
        public let password: String,
        public let method: String,
        public let local: String,
        public let localPort: UInt16
    ) {}

    public static func fromJson(r: JsonReader): Config {
        var server: String = ""
        var port: UInt16 = 0
        var password: String = ""
        var method: String = ""
        var local: String = ""
        var localPort: UInt16 = 0
        
        while (let Some(v) <- r.peek()) {
            match (v) {
                case BeginObject =>
                    r.startObject()
                    while (r.peek() != EndObject) {
                        let n = r.readName()
                        match (n) {
                            case "server" => server = r.readValue<String>()
                            case "server_port" => port = UInt16(r.readValue<Int>())
                            case "password" => password = r.readValue<String>()
                            case "method" => method = r.readValue<String>()
                            case "local" => local = r.readValue<String>()
                            case "local_port" => localPort = UInt16(r.readValue<Int>())
                            case _ => ()
                        }
                    }
                    r.endObject()
                    break
                case _ => throw Exception("Read config error, parse error.")
            }
        }
        return Config(server, port, password, method, local, localPort)
    }

    public override func toString(): String {
        return """
        {
            server: ${server}
            server_port: ${serverPort}
            password: ${password}
            method: ${method}
            local: ${local}
            local_port: ${localPort}
        }"""
    }

    public static func readConfig(): Config {
        Config.fromJson(JsonReader(File("shadowsocks.json", OpenOption.Open(true, false))))
    }
}
