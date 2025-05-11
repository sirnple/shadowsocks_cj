package shadowsocks_cj.sirnple.shadowsocks.config

import std.fs.{File, Path, FileInfo, OpenMode, exists, Directory}
import std.process.CurrentProcess

let HOME_DIR = CurrentProcess.current.homeDirectory.join(".shadowsocks_cj")


func findConfigFileForLog(): File {
    var configFilePath = Path("log.json")
    
    if (exists(configFilePath) && FileInfo(configFilePath).canRead()) {
        return File(configFilePath, OpenMode.Read)
    }

    let homeDir = HOME_DIR
    configFilePath = homeDir.join("log.json")
    if (exists(configFilePath) && FileInfo(configFilePath).canRead()) {
        return File(configFilePath, OpenMode.Read)
    }
    
    tryCreateHomeDir()
    File.create(configFilePath)
    File.writeTo(configFilePath,
    """
    {
        "log_level": "info"
    }""".toArray())
    return File(configFilePath, OpenMode.Read)
}

func findConfigFile(): File {
    var configFilePath = Path("shadowsocks.json")
    
    if (exists(configFilePath) && FileInfo(configFilePath).canRead()) {
        return File(configFilePath, OpenMode.Read)
    }

    configFilePath = HOME_DIR.join("shadowsocks.json")
    if (exists(configFilePath) && FileInfo(configFilePath).canRead()) {
        return File(configFilePath, OpenMode.Read)
    }

    tryCreateHomeDir()
    
    File.create(configFilePath)
    File.writeTo(configFilePath,
    """
    {
        "server": "0.0.0.0",
        "server_port": 1080,
        "local": "127.0.0.1",
        "local_port": 1081,
        "password": "password",
        "method": "sm4-128-cfb"
    }""".toArray())
    return File(configFilePath, OpenMode.Read)
}

private func tryCreateHomeDir() {
    if (!exists(HOME_DIR)) {
        Directory.create(HOME_DIR, recursive: true)
    }
}