package shadowsocks_cj.sirnple.shadowsocks.config

import encoding.json.stream.{JsonDeserializable, JsonReader, JsonToken}
import std.fs.{Path, File, OpenMode, exists, Directory, canonicalize, FileInfo}
import log.LogLevel
import std.process.CurrentProcess

public let LOG_CONFIG = LogConfig.readConfig()
public struct LogConfig <: JsonDeserializable<LogConfig> & ToString {
    public LogConfig(public let logLevel: LogLevel) {}

    public static func fromJson(r: JsonReader): LogConfig {
        var level = LogLevel.INFO

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
                                    case "all" => level = LogLevel.ALL
                                    case "trace" => level = LogLevel.TRACE
                                    case "debug" => level = LogLevel.DEBUG
                                    case "off" => level = LogLevel.OFF
                                    case "info" => level = LogLevel.INFO
                                    case "warn" => level = LogLevel.WARN
                                    case "error" => level = LogLevel.ERROR
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
        let logConfigFile = findConfigFile()
        return LogConfig.fromJson(JsonReader(logConfigFile))
    }

    private static func findConfigFile(): File {
        var configFilePath = Path("log.json")
        
        if (exists(configFilePath) && FileInfo(configFilePath).canRead()) {
            return File(configFilePath, OpenMode.Read)
        }
        configFilePath = CurrentProcess.current.homeDirectory.join(".shadowsocks_cj").join("log.json")
        if (exists(configFilePath) && FileInfo(configFilePath).canRead()) {
            return File(configFilePath, OpenMode.Read)
        }
        
        Directory.create(configFilePath, recursive: true)
        File.writeTo(configFilePath, """
        {
            log_level: "info"
        }""".toArray())
        return File(configFilePath, OpenMode.Read)
    }
}