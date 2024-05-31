from std import os.*
from std import os.process.*
from std import fs.*
from std import collection.*

let publishDir = Path("shadowsocks_cj")
let publishBinDir = publishDir.join("bin")
let publishLibDir = publishDir.join("lib")
let publishRuntimeDir = publishDir.join("runtime")

@When[debug]
let buildBinDir = Path("target/debug/bin")
@When[!debug]
let buildBinDir = Path("target/release/bin")
@When[debug]
let buildCrypto4CjDir = Path("target/debug/crypto4cj")
@When[!debug]
let buildCrypto4CjDir = Path("target/release/crypto4cj")
@When[debug]
let buildShadowsocksCjDir = Path("target/debug/shadowsocks_cj")
@When[!debug]
let buildShadowsocksCjDir = Path("target/release/shadowsocks_cj")

// 请根据自己的情况修改
@When[os == "linux"]
let libcryptoPath = Path("/home/sirnple/.cjpm/git/crypto4cj/a84a4ee959b30d27bd6a0dc9171a89f1c6aef7f4/lib/libcrypto.so")

func copyBinToPublishDir() {
    if (!Directory.exists(publishBinDir)) {
        Directory.create(publishBinDir, recursive: true)
    }
    Directory(buildBinDir).files() |> forEach { fileInfo: FileInfo => File.copy(fileInfo.path, publishBinDir.join(fileInfo.path.fileName??"unknown"), true)}
}

func copyLibsToPublishDir() {
    if (!Directory.exists(publishLibDir)) {
        Directory.create(publishLibDir, recursive: true)
    }
    Directory(buildCrypto4CjDir).files() |> concat(Directory(buildShadowsocksCjDir).files()) |> forEach { fileInfo: FileInfo => File.copy(fileInfo.path, publishLibDir.join(fileInfo.path.fileName??"unknown"), true)}
    File.copy(libcryptoPath, publishLibDir.join("libcrypto.so"), true)
}

func cleanPublishDir() {
    if (Directory.exists(publishDir)) {
        Directory.delete(publishDir, recursive: true)
    }
}

@When[os == "linux"]
func copyRuntimeToPublishDir() {
    match (os.getEnv("CANGJIE_HOME")) {
        case Some(cangjieHome) => Directory.copy(Path("${cangjieHome}/runtime/lib/linux_x86_64_llvm"), publishRuntimeDir, true)
        case None => ()
    }
}

@When[os == "windows"]
func copyRuntimeToPublishDir() {
    match (os.getEnv("CANGJIE_HOME")) {
        case Some(cangjieHome) => Directory.copy(Path("${cangjieHome}/runtime/lib/windows_x86_64_llvm"), publishRuntimeDir, true)
        case None => ()
    }
}

func copyConfigToPublishDir() {
    File.copy(Path("shadowsocks.json"), publishDir.join("shadowsocks.json"), true)
    File.copy(Path("log.json"), publishDir.join("log.json"), true)
}

let publishBall = Path("shadowsocks_cj.zip")
func zipPublishDir() {
    let exitCode = Process.run("zip", ["-r", publishBall.toString(), publishDir.toString()])
    if (exitCode != 0) {
        println("Zip failed, please zip it manually")
    }
}

func cleanOldPublish() {
    cleanPublishDir()
    if (File.exists(publishBall)) {
        File.delete(publishBall)
    }
}

func postBuild(): Int64 {
    cleanOldPublish()
    copyBinToPublishDir()
    copyLibsToPublishDir()
    copyRuntimeToPublishDir()
    copyConfigToPublishDir()
    zipPublishDir()
    cleanPublishDir()
    return 0
}

main() {
    match (os.getArgs()[0]) {
        case "post-build" => postBuild()
        case _ => 0
    }
}