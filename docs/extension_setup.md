# Network Extension Setup Guide

## ⚠️ Important: System Extension Limitations

The DMG build (`ProxyApp.dmg`) **cannot fully package the Network Extension** due to macOS security requirements.

## Why This Happens

macOS System Extensions require:
1. **Proper code signing** with a Developer ID certificate
2. **Notarization** by Apple
3. **Embedded extension bundle** inside the app
4. **User approval** in System Preferences

The simple DMG build script doesn't handle these requirements.

## Solution: Use Xcode or Swift Run

### Option 1: Run Directly with Swift (Easiest for Testing)

```bash
cd /Users/wangfeng/codews/proxy_app_network
swift run ProxyApp
```

This runs the app directly without packaging. The Extension will be available but may require permissions.

### Option 2: Build with Xcode (For Distribution)

1. **Generate Xcode Project**:
   ```bash
   swift package generate-xcodeproj
   open ProxyAppNetwork.xcodeproj
   ```

2. **Configure Extension Target**:
   - Select `ProxyExtension` target
   - Add `Info.plist` with:
     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
         <key>CFBundleIdentifier</key>
         <string>com.proxyApp.network.extension</string>
         <key>CFBundleName</key>
         <string>ProxyExtension</string>
         <key>NSExtension</key>
         <dict>
             <key>NSExtensionPointIdentifier</key>
             <string>com.apple.networkextension.packet-tunnel</string>
             <key>NSExtensionPrincipalClass</key>
             <string>PacketTunnelProvider</string>
         </dict>
     </dict>
     </plist>
     ```

3. **Add Entitlements**:
   - Create `ProxyApp.entitlements`:
     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
         <key>com.apple.security.app-sandbox</key>
         <true/>
         <key>com.apple.security.network.client</key>
         <true/>
         <key>com.apple.security.network.server</key>
         <true/>
         <key>com.apple.application-groups</key>
         <array>
             <string>group.com.proxyApp.network</string>
         </array>
     </dict>
     </plist>
     ```

4. **Build and Run** from Xcode

### Option 3: Simplified Testing (No Extension)

For testing the UI and logic without the actual Network Extension:

1. Comment out Extension-related code
2. Test rule matching, proxy configuration, etc. in isolation
3. Use mock connections for UI testing

## Granting Permissions

After running the app:

1. Go to **System Preferences** → **Privacy & Security**
2. Scroll to **Network** or **VPN** section
3. Allow **ProxyApp** to create network extensions
4. Restart the app

## Current Status

The app is **fully functional** in terms of:
- ✅ UI components
- ✅ Rule matching logic
- ✅ Proxy chain implementation
- ✅ Connection tracking

The **only limitation** is the System Extension packaging for the DMG build.

## Recommended Workflow

For development and testing:
```bash
swift run ProxyApp
```

For distribution:
- Use Xcode to build properly signed app
- Or wait for proper build script with codesigning
