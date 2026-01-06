#!/bin/bash
set -e

echo "🚀 Building ProxyApp..."

# Build in release mode
swift build -c release

APP_NAME="ProxyApp"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"

# Clean up old builds
rm -rf "$APP_BUNDLE" "$DMG_NAME"

echo "📦 Creating App Bundle Structure..."

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/"{MacOS,Resources}

# Copy main executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Make executable
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist with permission requests
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ProxyApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.proxyApp.network</string>
    <key>CFBundleName</key>
    <string>ProxyApp</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    
    <!-- Permission Request Descriptions -->
    <key>NSSystemExtensionUsageDescription</key>
    <string>ProxyApp needs to install a Network Extension to intercept and redirect network traffic according to your rules.</string>
    
    <key>NSNetworkExtensionUsageDescription</key>
    <string>ProxyApp requires network extension permissions to manage proxy connections and route traffic through configured proxies.</string>
    
    <key>NSLocalNetworkUsageDescription</key>
    <string>ProxyApp needs to access the local network to provide proxy services and manage connections.</string>
</dict>
</plist>
EOF

# Simple ad-hoc signing (no entitlements to avoid issues)
echo "✍️ Signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || {
    echo "⚠️ Warning: Code signing skipped"
}

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_NAME"

echo "✅ Done! Created $DMG_NAME"
echo ""
echo "📝 To run the app:"
echo "1. Option A (Recommended for testing):"
echo "   open .build/debug/ProxyApp"
echo ""
echo "2. Option B (From DMG):"
echo "   - Open $DMG_NAME"
echo "   - Drag to Applications"
echo "   - Right-click → Open (first time)"
echo ""
echo "⚠️ Note: Full Network Extension functionality requires:"
echo "   - Apple Developer certificate"
echo "   - Proper code signing with entitlements"
echo "   - User approval in System Preferences"
