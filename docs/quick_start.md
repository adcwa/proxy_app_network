# 快速开始指南

## 运行应用

```bash
cd /Users/wangfeng/codews/proxy_app_network

# 构建
swift build

# 启动（会打开 GUI 窗口）
open .build/debug/ProxyApp
```

## 基本使用

### 1. 添加代理服务器

1. 打开应用，切换到 **Proxies** 标签页
2. 点击 **Add Proxy**
3. 填写信息：
   - Name: 代理名称（如 "我的 SOCKS5"）
   - Type: SOCKS5 或 HTTP
   - Host: 代理服务器地址
   - Port: 端口号
   - Username/Password: 如需认证则填写
4. 点击 **Add**

### 2. 创建规则

1. 切换到 **Rules** 标签页
2. 点击 **Add Rule**
3. 配置规则：
   - **Rule Type**: 
     - Domain: 域名匹配（支持 `*.google.com`）
     - IP/CIDR: IP 范围（如 `192.168.0.0/16`）
     - Application: 应用程序（Bundle ID）
   - **Pattern**: 匹配模式
   - **Action**: 
     - Direct: 直连
     - Proxy: 选择代理服务器
4. 点击 **Add**

### 3. 启动代理

1. 切换到 **Settings** 标签页
2. 点击 **Install Profile / Initialize**
3. 点击 **Start Proxy**

**注意**：由于权限限制，可能会看到 "permission denied" 错误。这需要 Apple 开发者证书。

### 4. 查看连接

1. 切换到 **Connections** 标签页
2. 查看实时连接列表

## 规则示例

### 示例 1：Google 走代理
```
Type: Domain
Pattern: *.google.com
Action: Proxy (选择你的代理)
```

### 示例 2：本地网络直连
```
Type: IP/CIDR
Pattern: 192.168.0.0/16
Action: Direct
```

### 示例 3：特定应用走代理
```
Type: Application
Pattern: com.apple.safari
Action: Proxy
```

## 规则优先级

规则按**从上到下**的顺序匹配，**首次匹配**的规则生效。

例如：
1. `*.google.com` → Proxy
2. `*` → Direct

访问 `google.com` 会使用代理，其他网站直连。

## 故障排除

### 应用无法启动
确保使用 `open .build/debug/ProxyApp` 而不是 `swift run`。

### 权限错误
Network Extension 需要：
- Apple 开发者证书
- 代码签名
- 用户授权

当前可以测试 UI 和配置，但无法实际拦截流量。

### 连接列表为空
1. 确保 Extension 状态为 "Connected"
2. 尝试访问网站
3. 如果仍为空，检查 App Group 权限

## 更多信息

- 完整功能说明：`docs/project_summary.md`
- Extension 设置：`docs/extension_setup.md`
- 构建指南：`docs/setup_and_build.md`
