package shadowsocks_cj.sirnple.shadowsocks.config

import encoding.json.stream.{JsonDeserializable, JsonReader, JsonToken}
import std.fs.{File, OpenOption}
import std.log.LogLevel

public let LOG_CONFIG = LogConfig.readConfig()
public struct LogConfig <: JsonDeserializable<LogConfig> & ToString {
    public LogConfig(public let logLevel: LogLevel) {}

    public static func fromJson(r: JsonReader): LogConfig {
        var level = INFO

        while (let Some(v) <- r.peek()) {
            match (v) {
                case BeginObject =>
                    r.startObject()
                    while (r.peek() != EndObject) {
                        let n = r.readName()
                        match (n) {
                            case "log_level" =>
                                let levelStr = r.readValue<String>()
                                match (levelStr.toAsciiLower()) {
                                    case "all" => level = ALL
                                    case "trace" => level = TRACE
                                    case "debug" => level = DEBUG
                                    case "off" => level = OFF
                                    case "info" => level = INFO
                                    case "warn" => level = WARN
                                    case "error" => level = ERROR
                                    case _ => throw Exception("Invalid log level: ${levelStr}, only support ${LogLevel.ALL}, ${LogLevel.TRACE}, ${LogLevel.DEBUG}, ${LogLevel.INFO}, ${LogLevel.WARN}, ${LogLevel.ERROR}, ${LogLevel.OFF}")
                                }
                            case _ => ()
                        }
                    }
                    r.endObject()
                    break
                case _ => throw Exception("Read config error, parse error.")
            }
        }
        return LogConfig(level)
    }

    public override func toString(): String {
        return """
        {
            log_level: ${logLevel}
        }"""
    }

    public static func readConfig(): LogConfig {
        LogConfig.fromJson(JsonReader(File("log.json", OpenOption.Open(true, false))))
    }
}