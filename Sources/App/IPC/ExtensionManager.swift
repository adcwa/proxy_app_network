import Foundation
import NetworkExtension

class ExtensionManager: ObservableObject {
    static let shared = ExtensionManager()
    
    @Published var status: NEVPNStatus = .disconnected
    @Published var isEnabled = false
    @Published var lastError: String?
    
    private var manager: NETunnelProviderManager?
    
    private init() {
        loadManager()
        
        NotificationCenter.default.addObserver(self, selector: #selector(statusDidChange), name: .NEVPNStatusDidChange, object: nil)
    }
    
    @objc private func statusDidChange(_ notification: Notification) {
        // Reload status from the manager connection
        // Note: The notification object might be the NEVPNConnection
        guard let connection = notification.object as? NEVPNConnection else { return }
        DispatchQueue.main.async {
            self.status = connection.status
        }
    }
    
    func loadManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = "Load Error: \(error.localizedDescription)"
                    return
                }
                
                self?.manager = managers?.first ?? NETunnelProviderManager()
                self?.isEnabled = self?.manager?.isEnabled ?? false
                self?.status = self?.manager?.connection.status ?? .disconnected
            }
        }
    }
    
    func installProfile() {
        // Creating a new manager effectively installs the profile if saved
        loadManager()
    }
    
    func startExtension() {
        guard let manager = self.manager else {
            lastError = "Manager not loaded"
            return
        }
        
        manager.loadFromPreferences { [weak self] error in
            if let error = error {
                DispatchQueue.main.async { self?.lastError = "Load Prefs Error: \(error.localizedDescription)" }
                return
            }
            
            // Setup protocol configuration
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = "com.proxyApp.network.extension"
            protocolConfiguration.serverAddress = "127.0.0.1"
            
            manager.protocolConfiguration = protocolConfiguration
            manager.isEnabled = true
            
            manager.saveToPreferences { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async { self?.lastError = "Save Prefs Error: \(error.localizedDescription)" }
                } else {
                    // Start the tunnel
                    do {
                        try manager.connection.startVPNTunnel()
                    } catch {
                        DispatchQueue.main.async { self?.lastError = "Start Tunnel Error: \(error.localizedDescription)" }
                    }
                }
            }
        }
    }
    
    func stopExtension() {
        manager?.connection.stopVPNTunnel()
    }
    
    func sendRuleUpdate() {
        guard let manager = self.manager,
              let session = manager.connection as? NETunnelProviderSession else {
            lastError = "Cannot send message: Extension not connected"
            return
        }
        
        do {
            try session.sendProviderMessage("reload_rules".data(using: .utf8)!) { response in
                if let response = response, let msg = String(data: response, encoding: .utf8) {
                    print("Extension response: \(msg)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.lastError = "Failed to send message: \(error.localizedDescription)"
            }
        }
    }
}
