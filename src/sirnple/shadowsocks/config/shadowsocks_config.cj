package shadowsocks_cj.sirnple.shadowsocks.config

import encoding.json.stream.{JsonDeserializable, JsonReader, JsonToken}
import std.fs.*
import std.io.*


public let SUPPORT_METHOD = ["sm4-128-gcm", "sm4-128-cfb"]

public func isSupportMethod(method: String): Bool {
    return SUPPORT_METHOD.contains(method.toAsciiLower())
}

public struct ShadowsocksConfig <: JsonDeserializable<ShadowsocksConfig> & ToString {
    public ShadowsocksConfig(
        public let server: String,
        public let serverPort: UInt16,
        public let password: String,
        public let method: String,
        public let local: String,
        public let localPort: UInt16
    ) {}

    public static func fromJson(r: JsonReader): ShadowsocksConfig {
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
                            case "method" =>
                                let uncheckedMethod = r.readValue<String>()
                                if (!isSupportMethod(uncheckedMethod)) {
                                    throw Exception("Read config error, method ${uncheckedMethod} not support, support: ${String.join(SUPPORT_METHOD, delimiter: ", ")}")
                                }
                                method = uncheckedMethod
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
        return ShadowsocksConfig(server, port, password, method, local, localPort)
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

    public static func readConfig(): ShadowsocksConfig {
        ShadowsocksConfig.fromJson(JsonReader(File("shadowsocks.json", OpenOption.Open(true, false))))
    }
}