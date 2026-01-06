import Foundation
import NetworkExtension

class ExtensionManager: ObservableObject {
    static let shared = ExtensionManager()
    
    @Published var isEnabled = false
    
    func installProfile() {
        // Logic to save profile to disk and notify extension
    }
    
    func startExtension() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                print("Failed to load preferences: \(error)")
                return
            }
            
            let manager = managers?.first ?? NETunnelProviderManager()
            
            // Setup protocol configuration
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = "com.proxyApp.network.extension"
            protocolConfiguration.serverAddress = "127.0.0.1"
            
            manager.protocolConfiguration = protocolConfiguration
            manager.isEnabled = true
            
            manager.saveToPreferences { error in
                if let error = error {
                    print("Failed to save preferences: \(error)")
                } else {
                    // Start the tunnel
                    do {
                        try manager.connection.startVPNTunnel()
                    } catch {
                        print("Failed to start tunnel: \(error)")
                    }
                }
            }
        }
    }
    
    func stopExtension() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard let manager = managers?.first else { return }
            manager.connection.stopVPNTunnel()
        }
    }
}
