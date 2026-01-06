# Build and Setup Guide

## Prerequisites
*   macOS 12.0 or later
*   Xcode 14.0 or later
*   Apple Developer Account (Required for Network Extensions)

## Quick Start (Recommended)

This project is configured as a Swift Package. You can open and build it directly in Xcode or via CLI.

### Option 1: Swift Package Manager (CLI)
1. Open Terminal in the project root.
2. Run `swift build` to verify compilation.
3. Run `swift run ProxyApp` (Note: running from CLI might have limitations regarding System Extension capabilities compared to an installed App Bundle).

### Option 2: Xcode (Open Package)
1. Open the project folder in `Xcode` (`File > Open...` -> select folder).
2. Xcode will detect `Package.swift` and load the scheme.
3. Select the `ProxyApp` scheme.
4. Verify signing settings in the project editor if needed (though SPM handles basic signing).
5. Click **Run** (Cmd+R).

### Option 3: Create DMG (Local Install)
If you need a `.dmg` file for distribution or local installation:
1. Run `bash scripts/build_dmg.sh`.
2. This creates `ProxyApp.dmg` in the project root.
3. **Note**: The app bundle created this way is ad-hoc signed. System Extensions might not behave correctly without full Xcode distribution signing (with a Developer ID).

## Prerequisites
*   macOS 12.0 or later
*   Xcode 14.0 or later
*   Apple Developer Account (Required for Network Extensions)

## Advanced Setup: Xcode Project Generation (For Full Distribution)
If you need to strictly manage entitlements, creating a `.xcodeproj` is recommended.

1.  **Generate Project** (Optional):
    *   SwiftPM can generate an Xcode project: `swift package generate-xcodeproj` (Note: deprecated in favor of direct open, but creates a project file).
    *   **Or Manual Creation** (Recommended for System Extensions):

2.  **Manual Project Setup**
    *   Create a new Xcode Workspace or Project.
    *   Add the `Sources/App` folder as the Main App Target.
    *   Add the `Sources/Extension` folder as a `Network Extension` Target (Packet Tunnel).
    *   Add `Packages/ProxyEngine` as a Local Swift Package dependency.

3.  **Link Dependencies**
    *   **App Target**:
        *   Frameworks: `ProxyEngine`, `SystemExtensions`, `NetworkExtension`.
        *   Embed App Extensions: Select the Extension target.
    *   **Extension Target**:
        *   Frameworks: `ProxyEngine`, `NetworkExtension`.

## Configuration & Signing

> [!IMPORTANT]
> Network Extensions **require** a valid provisioning profile with specific entitlements.

1.  **App Target Signing**:
    *   Check "Automatically manage signing".
    *   Select your Development Team.
    *   Add Capability: **System Extension**.
    *   Add Capability: **App Groups** (Create unique group ID).
    *   Add Capability: **Network Extensions** (if managing VPN preferences from App).

2.  **Extension Target Signing**:
    *   Check "Automatically manage signing".
    *   Select your Development Team.
    *   Add Capability: **Network Extensions** -> Check **Packet Tunnel**.
    *   Add Capability: **App Groups** (Use same ID as App).

3.  **Info.plist**:
    *   In the Extension's `Info.plist`, ensure `NEMachServiceName` matches your group ID if using XPC.

## Running the App

1.  Select the **App** scheme in Xcode.
2.  Click **Run** (Cmd+R).
3.  On first launch:
    *   Click "Install Extension" in the Settings tab.
    *   **System Alert**: macOS will ask permission to add a Proxy Configuration. Click **Allow**.
    *   **System Settings**: You might be prompted to enable the System Extension in "Privacy & Security".

## Debugging

*   **View Logs**: Open `Console.app` and filter by the extension's Bundle ID (e.g., `com.proxyApp.network.extension`).
*   **Attach Debugger**: In Xcode, go to `Debug > Attach to Process` and select your extension process.
