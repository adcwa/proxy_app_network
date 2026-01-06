# Release and Distribution Guide

## 1. Preparing for Release

### Code Signing
*   Ensure you have a **Developer ID Application** certificate for distribution outside the Mac App Store.
*   Ensure you have a **Mac App Store** certificate if distributing via MAS.

### Entitlements
*   **Important**: Network Extensions distributed with Developer ID require a specific entitlement (`com.apple.developer.networking.networkextension`) that must be granted by Apple for `Developer ID` signing.
    *   For testing (Development), this is automatic.
    *   For Release (Developer ID), you usually need to request this capability or check your Apple Developer account features.

## 2. Archiving

1.  **Clean Build Folder**: `Product > Clean Build Folder` (Cmd+Shift+K).
2.  **Archive**: Select `Generic macOS Device` destination, then `Product > Archive`.
3.  **Validate**: Once archived, the Organizer window will open. Click "Validate App" to check for signing issues.

## 3. Distribution Methods

### A. Direct Distribution (Notarization)
1.  **Export**: In Organizer, click "Distribute App" -> "Developer ID" -> "Upload" (to send to Apple for Notarization).
2.  **Notarize**: Apple will scan the binary for malware. This usually takes a few minutes.
3.  **Staple**: Once approved, Xcode will "staple" the ticket to your App.
4.  **Package**:
    *   Create a `.dmg` or `.pkg` installer.
    *   **Note**: Using a `.pkg` is recommended for System Extensions as pre-install/post-install scripts can sometimes help clean up old versions (though `OSS` usually handles this).

### B. Mac App Store
1.  **Export**: Click "Distribute App" -> "App Store Connect".
2.  **Upload**: Upload build to TestFlight/App Store.

## 4. Updates (Sparkle)
For non-MAS distribution, integrating **Sparkle** is recommended.
1.  Add `Sparkle` framework.
2.  Configure `SUFeedURL` in `Info.plist`.
3.  Sign the update `.dmg` with the same Developer ID certificate.
4.  Generate the `appcast.xml` using `generate_appcast`.

## Common Pitfalls
*   **Embedded Provisioning Profiles**: Ensure the Extension's profile is embedded correctly in the main app bundle `Contents/PlugIns/`. Xcode handles this automatically during Archive.
*   **Entitlement mismatch**: The App Group IDs must match exactly between App and Extension.
