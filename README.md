# ProxyApp

一个基于 macOS Network Extension 的系统级代理工具，实现类似 Proxifier 的透明代理功能。

## 功能特性

- ✅ **SOCKS5/HTTP 代理支持**：完整的协议实现
- ✅ **高级规则系统**：域名通配符、CIDR IP 范围、应用程序匹配
- ✅ **代理链**：支持通过远程代理连接
- ✅ **实时连接跟踪**：查看所有活动连接
- ✅ **完整的管理 UI**：规则、代理、连接、设置

## 快速开始

```bash
# 构建
swift build

# 运行
open .build/debug/ProxyApp
```

## 使用示例

### 1. 添加代理服务器
Proxies 标签页 → Add Proxy → 填写信息 → Add

### 2. 创建规则
Rules 标签页 → Add Rule → 配置规则 → Add

**规则示例**：
- `*.google.com` → Proxy（Google 走代理）
- `192.168.0.0/16` → Direct（本地网络直连）

### 3. 启动代理
Settings 标签页 → Start Proxy

## 文档

- [快速开始](docs/quick_start.md) - 基本使用指南
- [项目总结](docs/project_summary.md) - 完整功能说明
- [构建指南](docs/setup_and_build.md) - 编译和打包
- [Extension 设置](docs/extension_setup.md) - Network Extension 配置

## 项目结构

```
ProxyApp/
├── Sources/
│   ├── App/              # UI 应用
│   └── Extension/        # Network Extension
├── Packages/
│   └── ProxyEngine/      # 核心代理引擎
├── docs/                 # 文档
└── scripts/              # 构建脚本
```

## 技术栈

- **语言**: Swift
- **UI**: SwiftUI
- **网络**: Network.framework
- **扩展**: Network Extension (PacketTunnelProvider)
- **构建**: Swift Package Manager

## 已知限制

由于 macOS 安全限制，Network Extension 需要：
- Apple 开发者证书
- 代码签名
- 用户授权

当前可以测试 UI 和配置功能，实际流量拦截需要正式签名。

## 开发状态

✅ **MVP 完成** - 所有核心功能已实现：
- 代理协议（SOCKS5、HTTP）
- 规则匹配（通配符、CIDR）
- 代理链
- 连接跟踪
- 完整 UI

## License

MIT

## 作者

ProxyApp Development Team
