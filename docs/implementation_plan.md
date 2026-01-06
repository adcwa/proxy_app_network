# Implementation Plan - macOS System Proxy Tool

## Goal Description
Build a macOS system-level network redirector using the Network Extension framework. The app will intercept TCP/DNS traffic and forward it to specified proxies (SOCKS5/HTTP) based on user-defined rules.
The goal is to deliver a "compile-ready" project structure with core logic implemented.

## User Review Required
> [!IMPORTANT]
> **System Extension Signing**: The user must have an Apple Developer Account to sign and run Network Extensions. I cannot sign the code for them.
> **Environment Limits**: I cannot run/debug the full UI application or the System Extension in this environment. I will provide the full source code and a verification guide.

## Proposed Changes

### Project Structure Strategy
I will create a standard Xcode project structure (on the file system) with a Swift Package for the core logic to allow for modular testing.

```
/Users/wangfeng/codews/proxy_app_network/
├── MyProxifier.xcodeproj/          # (Simulated project structure)
├── Sources/
│   ├── App/                        # Main UI App (SwiftUI)
│   ├── Extension/                  # NEPacketTunnelProvider
│   └── Shared/                     # IPC protocols, Data Models
├── Packages/
│   └── ProxyEngine/                # Core Logic (SOCKS/HTTP/Rules) - Testable
├── docs/                           # Documentation
└── Package.swift                   # For the ProxyEngine (if using SPM for core)
```

### [New] ProxyEngine Package
*   **Location**: `Packages/ProxyEngine`
*   **Purpose**: Isolate the logic for SOCKS5/HTTP protocols and Rule Matching.
*   **Files**:
    *   `Sources/ProxyEngine/Protocols/SOCKS5.swift`: SOCKS5 handshake and framing.
    *   `Sources/ProxyEngine/Protocols/HTTPProxy.swift`: HTTP CONNECT handling.
    *   `Sources/ProxyEngine/Rules/RuleManager.swift`: Trie-based domain matching, IP range matching.
    *   `Sources/ProxyEngine/Core/ConnectionManager.swift`: Manages active connections.

### [New] Network Extension
*   **Location**: `Sources/Extension`
*   **Files**:
    *   `PacketTunnelProvider.swift`: Subclass of `NEPacketTunnelProvider`.
    *   `FlowCopier.swift`: Bridges `NEPacketTunnelFlow` to the `ProxyEngine`.

### [New] UI Application
*   **Location**: `Sources/App`
*   **Files**:
    *   `AppMain.swift`: Entry point.
    *   `Views/`: SwiftUI views (ConnectionList, RuleEditor, SetupView).
    *   `IPC/ExtensionManager.swift`: Manages XPC connection to the extension.

## Verification Plan

### Automated Tests
I will assume the use of `swift test` for the `ProxyEngine` package.
*   **Command**: `cd Packages/ProxyEngine && swift test`
*   **Coverage**:
    *   SOCKS5 Encoding/Decoding.
    *   Rule Matching (Domain wildcards, IP ranges).
    *   Configuration parsing (.ppx/json).

### Manual Verification (User)
1.  **Build**: Open the project in Xcode.
2.  **Sign**: Set Development Team for both targets (App & Extension).
3.  **Run**: Launch the App.
4.  **Install**: Click "Install Extension" in the UI.
5.  **Test**:
    *   Configure a SOCKS5 proxy (e.g., local `ssh -D`).
    *   Add a rule (e.g., "All Traffic" -> Proxy).
    *   Open Safari and verify traffic appears in the "Connections" list.
