# shadowsocks_cj 仓库总结

## 一、项目概述

**shadowsocks_cj** 是一个使用仓颉（Cangjie）编程语言实现的 Shadowsocks 代理服务器项目。这是 Shadowsocks 协议的一个原创实现，旨在提供安全、高效的网络代理服务。

### 基本信息
- **项目名称**: shadowsocks_cj
- **编程语言**: 仓颉（Cangjie）
- **版本**: 1.0.0
- **仓颉编译器版本**: 0.58.3
- **开源许可证**: 木兰宽松许可证 第2版（MulanPSL2）

## 二、软件架构

### 2.1 核心组件

项目采用客户端-服务器（Client-Server）架构，包含两个主要可执行程序：

1. **ss-local（本地客户端）**
   - 包名: `shadowsocks_cj.sirnple.shadowsocks.local`
   - 功能: 在本地运行，接收客户端应用的 SOCKS5 请求
   - 默认监听: 127.0.0.1:1081

2. **ss-remote（远程服务器）**
   - 包名: `shadowsocks_cj.sirnple.shadowsocks.remote`
   - 功能: 在远程服务器运行，代理访问目标网站
   - 默认监听: 0.0.0.0:1080

### 2.2 目录结构

```
shadowsocks_cj/
├── src/sirnple/shadowsocks/
│   ├── config/          # 配置管理模块
│   │   ├── LogConfig.cj           # 日志配置
│   │   ├── common.cj              # 通用配置
│   │   └── shadowsocks_config.cj  # Shadowsocks配置
│   ├── core/            # 核心功能模块
│   │   ├── crypto.cj              # 加密解密实现
│   │   ├── crypto_test.cj         # 加密测试
│   │   ├── DstAddr.cj             # 目标地址处理
│   │   ├── protocol_const.cj      # 协议常量
│   │   ├── protocol_const_test.cj # 协议测试
│   │   ├── cj_extension.cj        # 扩展功能
│   │   └── cj_extension_test.cj   # 扩展测试
│   ├── local/           # 本地客户端模块
│   │   ├── main.cj                # 本地客户端入口
│   │   ├── TcpServer.cj           # TCP服务器
│   │   ├── TcpHandler.cj          # TCP处理器
│   │   └── Status.cj              # 状态管理
│   ├── remote/          # 远程服务器模块
│   │   ├── main.cj                # 远程服务器入口
│   │   ├── TcpServer.cj           # TCP服务器
│   │   ├── TcpHandler.cj          # TCP处理器
│   │   └── Status.cj              # 状态管理
│   └── util/            # 工具模块
│       └── assert.cj              # 断言工具
├── doc/                 # 文档目录
│   └── ShadowSocks协议.md # 协议说明文档
├── build.cj             # 构建脚本
├── cjpm.toml            # 项目配置文件
├── shadowsocks.json     # Shadowsocks运行配置
├── log.json             # 日志配置
└── README.md            # 项目说明文档
```

### 2.3 代码规模

- 源代码文件数量: 22个 .cj 文件
- 包含单元测试
- 完整的配置管理系统

## 三、技术特性

### 3.1 加密算法支持

项目目前支持以下加密方法：
- **SM4-128-CFB**: SM4加密算法的CFB模式
- **SM4-128-GCM**: SM4加密算法的GCM模式

SM4是中国国家密码管理局发布的商用密码算法，具有高安全性。

### 3.2 核心功能

1. **协议支持**
   - SOCKS5协议实现
   - Shadowsocks加密传输协议
   - 支持TCP转发

2. **加密系统**
   - 实现了完整的加密/解密接口 `ShadowsocksCryptor`
   - 支持首次加密和后续加密
   - IV向量长度: 16字节
   - 使用MD5派生密钥

3. **配置管理**
   - JSON格式配置文件
   - 支持服务器地址、端口、密码、加密方法等配置
   - 灵活的日志配置系统

### 3.3 工作流程

```
客户端应用 → ss-local → ss-remote → 目标服务器
           (SOCKS5)   (加密传输)   (明文访问)
```

详细流程：
1. 客户端应用与 ss-local 建立 SOCKS5 连接
2. ss-local 将目标地址以加密格式发送给 ss-remote
3. ss-remote 解密后访问目标服务器
4. ss-remote 将响应加密后返回给 ss-local
5. ss-local 解密并转发给客户端应用

## 四、性能表现

### 4.1 基准测试

使用 ab-proxy 工具进行性能测试（1000请求，并发度10）：

| 测试场景 | 平均请求速率 (req/s) | 相对性能 |
|---------|---------------------|---------|
| 不使用代理 | 616.1 | 100% |
| shadowsocks_cj | 555.1 | 90% |
| Python版本Shadowsocks | 566.2 | 92% |

**测试结论**：
- shadowsocks_cj 的性能达到 Python 版本的 98%
- 相比不使用代理，性能损失约 10%
- 性能表现接近业界成熟实现

## 五、构建与发布

### 5.1 构建系统

- 使用 cjpm（Cangjie Package Manager）进行项目管理
- 提供自动化构建脚本 `build.cj`
- 支持 Linux 和 Windows 平台
- 自动打包发布（Linux: tar.gz, Windows: zip）

### 5.2 构建流程

```
编译 → 复制可执行文件 → 复制配置文件 → 打包压缩
```

## 六、配置示例

默认配置文件 `shadowsocks.json`：
```json
{
    "server": "0.0.0.0",
    "server_port": 1080,
    "local": "127.0.0.1",
    "local_port": 1081,
    "password": "password",
    "method": "sm4-128-cfb"
}
```

## 七、开发计划（Todo List）

- [ ] 性能优化
- [ ] 支持 UDP 协议
- [x] 完备加密算法支持

## 八、项目特点

### 优势

1. **语言创新**: 使用仓颉语言实现，这是一个相对较新的编程语言
2. **国密支持**: 原生支持SM4国密算法
3. **架构清晰**: 模块化设计，代码结构清晰
4. **性能优秀**: 性能接近Python版本的成熟实现
5. **测试完善**: 包含单元测试，保证代码质量

### 应用场景

- 网络代理服务
- 加密通信
- 流量转发
- 安全访问受限资源

## 九、技术栈

- **核心语言**: 仓颉（Cangjie）
- **加密库**: std.crypto（标准加密库）、crypto（自定义加密模块）
- **网络库**: 标准网络库
- **日志系统**: logger.SimpleLogger
- **序列化**: JSON（encoding.json）

## 十、贡献指南

1. Fork 本仓库
2. 创建特性分支（Feat_xxx）
3. 提交代码
4. 创建 Pull Request

## 十一、总结

shadowsocks_cj 是一个设计良好、实现完整的 Shadowsocks 代理服务器项目。它展示了如何使用仓颉语言开发网络应用，并在性能和功能上达到了生产可用的水平。项目代码结构清晰，模块化程度高，支持国密算法，是学习网络代理和仓颉语言的优秀参考实现。

该项目特别适合：
- 仓颉语言学习者
- 网络代理技术研究者
- 需要国密算法支持的应用场景
- 对网络安全和加密通信感兴趣的开发者
