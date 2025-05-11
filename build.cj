import std.process.{Process}
import std.fs.*
import std.collection.*

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

@When[os == 'Windows']
func copyBinToPublishDir() {
    if (!exists(publishBinDir)) {
        Directory.create(publishBinDir, recursive: true)
    }
    Directory.walk(buildBinDir) {
        fileInfo => 
        copy(fileInfo.path, to: publishBinDir.join(fileInfo.path.fileName), overwrite: true)
        return true
    }
}

@When[os == 'Linux']
func copyBinToPublishDir() {
    if (!exists(publishBinDir)) {
        Directory.create(publishBinDir, recursive: true)
    }

    copy(publicBinDir.join('shadowsocks_cj.sirnple.shadowsocks.local'), to: publishBinDir.join('shadowsocks_cj.sirnple.shadowsocks.local'), overwrite: true)
    copy(publicBinDir.join('shadowsocks_cj.sirnple.shadowsocks.remote'), to: publishBinDir.join('shadowsocks_cj.sirnple.shadowsocks.remote'), overwrite: true)
}

func cleanPublishDir() {
    if (exists(publishDir)) {
        remove(publishDir, recursive: true)
    }
}

@When[os == 'Windows']
func copyRuntimeToPublishDir() {
    match (Process.current.getEnv("CANGJIE_HOME")) {
        case Some(cangjieHome) => copy(Path("${cangjieHome}/runtime/lib/windows_x86_64_llvm"), to: publishRuntimeDir, overwrite: true)
        case None => ()
    }
}

func copyConfigToPublishDir() {
    copy(Path("shadowsocks.json"), to: publishDir.join("shadowsocks.json"), overwrite: true)
    copy(Path("log.json"), to: publishDir.join("log.json"), overwrite: true)
}

let publishBallForLinux = Path("shadowsocks_cj.tar.gz")
let publishBallForWindows = Path("shadowsocks_cj.zip")

@When[os == "Linux"]
func zipPublishDir() {
    let exitCode = Process.run("tar", ["-czf", publishBallForLinux.toString(), publishDir.toString()])
    if (exitCode != 0) {
        println("tar failed")
    }
}

@When[os == "Windows"]
func zipPublishDir() {
    var exitCode = -1
    try {
        exitCode = Process.run("7z")
    } catch (e: Exception) {
        println("7z not found, please install 7z first")
        Process.current.exit(-1)
    }
    exitCode = Process.run("7z", ["a", publishBallForWindows.toString(), publishDir.toString()])
    if (exitCode != 0) {
        println("Zip failed, please zip it manually")
        Process.current.exit(-1)
    }
}

func cleanOldPublish() {
    cleanPublishDir()
    if (exists(publishBallForLinux)) {
        remove(publishBallForLinux)
    }
    if (exists(publishBallForWindows)) {
        remove(publishBallForWindows)
    }
}

@When[os == 'Windows']
func postBuild(): Int64 {
    cleanOldPublish()
    copyBinToPublishDir()
    copyRuntimeToPublishDir()
    copyConfigToPublishDir()
    zipPublishDir()
    cleanPublishDir()
    return 0
}

@When[os == 'Linux']
func postBuild(): Int64 {
    cleanOldPublish()
    copyBinToPublishDir()
    copyConfigToPublishDir()
    zipPublishDir()
    cleanPublishDir()
    return 0
}

main() {
    match (Process.current.arguments[0]) {
        case "post-build" => postBuild()
        case _ => 0
    }
}