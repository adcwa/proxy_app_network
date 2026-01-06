# 一、产品定位与目标（macOS First）

## 1. 产品目标

在 macOS 上实现一款 **系统级网络代理重定向工具**，核心能力是：

> **无需修改应用配置，将任意应用的 TCP / DNS 流量透明转发到指定代理（SOCKS / HTTP / HTTPS / Chain）**

目标对标 Proxifier，但**第一阶段做“可用 + 稳定 + 可维护”**，而不是全功能堆满。

---

## 2. MVP 优先级（macOS v1）

**必须有**

* TCP 透明代理（SOCKS5 / HTTP）
* 按应用 + 目标地址规则转发
* DNS over Proxy
* 代理失败自动 fallback
* 可视化连接列表
* Profile 配置文件

**可延后**

* Kerberos / NTLM
* Proxy Chain UI 拖拽
* 流量抓包
* Android / Windows

---

# 二、macOS 下的核心技术难点

macOS 与 Windows 最大区别是：
👉 **你不能随意 hook socket API**

所以方案必须基于 **Apple 官方网络扩展能力**

---

## macOS 可行方案对比

| 方案                     | 能力    | 可行性    | 说明                   |
| ---------------------- | ----- | ------ | -------------------- |
| Network Extension (NE) | ⭐⭐⭐⭐⭐ | ✅ 官方推荐 | Proxifier mac 本质也是这个 |
| pf / ipfw              | ⭐⭐    | ❌ 不稳定  | 权限高、不可控              |
| LD_PRELOAD             | ❌     | ❌      | mac 不支持              |
| VPN TUN                | ⭐⭐⭐⭐  | ⚠️     | 可行但复杂                |

✅ **最终选择：Network Extension + Packet Tunnel**

---

# 三、总体架构设计（macOS）

```
+---------------------------+
|        UI App             |
|  Swift / SwiftUI / AppKit |
|---------------------------|
              |
              | IPC (XPC)
              v
+---------------------------+
|  System Extension (NE)    |
|  Packet Tunnel Provider   |
|  Network Filter           |
+---------------------------+
              |
              | TCP / DNS Redirect
              v
+---------------------------+
| Proxy Engine              |
| SOCKS / HTTP / Chain      |
+---------------------------+
              |
              v
        Remote Proxy
```

---

## 架构分层说明

### 1️⃣ UI App（用户态）

* 配置规则
* 查看连接
* Profile 管理
* 启停代理

### 2️⃣ Network Extension（内核态 + 用户态桥）

* 拦截系统网络流量
* 获取 **应用信息（bundle id / pid）**
* 重定向 TCP / DNS

### 3️⃣ Proxy Engine（核心）

* 实现 SOCKS / HTTP 协议
* Failover / Chain
* DNS over Proxy
* 流量统计

---

# 四、核心模块需求分析 + 技术方案

---

## 1️⃣ 流量拦截（最核心）

### 技术选型

* `NEPacketTunnelProvider`
* `NENetworkRule`
* `NETransparentProxyManager`（新系统可用）

### 能力

* 拦截所有 TCP 出站连接
* 获取：

  * 源应用 PID / bundle id
  * 目标 IP / Port
* 将流量送入自定义代理引擎

### 关键点

* **不是 VPN UI，而是 Transparent Proxy**
* 不改系统代理设置
* 对 App 无感知

---

## 2️⃣ 代理协议支持

### v1 支持列表

* SOCKS5（用户名/密码）
* HTTP Proxy（CONNECT）
* HTTPS（显式）

### 内部接口设计

```swift
protocol ProxyAdapter {
    func connect(target: Host, port: Int) -> ProxyConnection
}
```

支持：

* IPv4 / IPv6
* TCP only（UDP 后续）

---

## 3️⃣ Proxy Chain / Failover 设计

### 抽象模型

```text
Rule
 └── Chain
      ├── Proxy A
      ├── Proxy B
      └── Proxy C
```

### 执行策略

* Failover：A 失败 → B
* Load balance：hash(app + host)
* 超时可配置

---

## 4️⃣ DNS 处理（非常重要）

### 模式支持

* System DNS
* DNS over Proxy
* Hybrid（自动识别）

### 实现方式

* 拦截 53 / DoH
* DNS Query → Proxy → Remote DNS
* 缓存 + TTL 管理

---

## 5️⃣ 规则系统（Proxifier 灵魂）

### 规则维度

* Application（bundle id / path）
* Hostname（支持 wildcard）
* IP Range
* Port Range

### 规则 DSL 示例

```text
Rule 1:
  App: Safari
  Host: *.google.com
  Action: ProxyChain(GoogleChain)

Rule 2:
  IP: 192.168.*.*
  Action: Direct
```

### 技术实现

* 编译期规则树（Trie + Range Map）
* 从上到下匹配
* O(log n)

---

## 6️⃣ Profile 系统（企业级能力）

### Profile 文件

* `.ppx` 兼容
* XML / JSON
* AES-256 加密敏感字段

### 功能

* 快速切换
* 远程拉取
* 静默加载

```bash
myproxifier load profile.ppx --silent
```

---

## 7️⃣ UI 与交互（macOS）

### 技术选型

* SwiftUI（主 UI）
* AppKit（托盘 & 高级表格）

### 核心界面

* Connections（实时）
* Rules
* Proxies
* Profiles
* Logs

### 实时连接展示

* App
* Host
* Proxy
* Status
* Bytes In/Out

---

## 8️⃣ 日志 & 排错系统

### 日志等级

* Error
* Warn
* Info
* Debug

### 高级能力

* 单连接流量 dump
* 代理失败原因链路
* 启动自检

---

# 五、系统权限 & 安装设计（macOS）

## 权限需求

* Network Extension
* System Extension
* Full Disk Access（可选）

## 安装

* `.pkg` 安装包
* 用户授权 Extension
* 自动升级（Sparkle）

---

# 六、开发技术栈总结

| 层级         | 技术                |
| ---------- | ----------------- |
| UI         | SwiftUI + AppKit  |
| System     | Network Extension |
| Proxy Core | Swift + C++（可混合）  |
| 加密         | CryptoKit         |
| IPC        | XPC               |
| 构建         | Xcode             |
| 更新         | Sparkle           |

---

# 七、阶段性开发计划（建议）

## Phase 1（4–6 周）

* TCP 透明代理
* SOCKS5
* App + Host 规则
* 基础 UI

## Phase 2（4 周）

* DNS over Proxy
* Failover
* Profile
* 日志系统

## Phase 3（增强）

* Proxy Chain UI
* 流量图表
* 企业配置