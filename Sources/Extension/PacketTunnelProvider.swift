import NetworkExtension
import ProxyEngine
import os.log
import Network

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let socksProxy = SOCKS5Proxy()
    private let httpProxy = HTTPProxy()
    private var httpListener: NWListener?
    private var socksListener: NWListener?
    private let httpPort: UInt16 = 9090
    private let socksPort: UInt16 = 9091
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting Tunnel Provider...", log: .default, type: .info)
        
        // 1. Start Local Proxy Servers
        do {
            try startHTTPListener()
            try startSOCKSListener()
        } catch {
            os_log("Failed to start local servers: %{public}@", log: .default, type: .error, error.localizedDescription)
            completionHandler(error)
            return
        }
        
        // 2. Configure System Proxy Settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")
        settings.mtu = 1500
        
        let proxySettings = NEProxySettings()
        // HTTP / HTTPS -> 9090
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: Int(httpPort))
        
        // SOCKS Direct setting not available in NEProxySettings, using PAC instead for full coverage
        // proxySettings.autoProxyConfigurationEnabled = true
        // proxySettings.proxyAutoConfigURL = URL(string: "http://127.0.0.1:\(httpPort)/proxy.pac")
        
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: Int(httpPort))
        
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: Int(httpPort))
        
        proxySettings.excludeSimpleHostnames = true
        proxySettings.exceptionList = ["127.0.0.1", "localhost", "192.168.0.0/16", "10.0.0.0/8"]
        
        settings.proxySettings = proxySettings
        
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = []
        settings.ipv4Settings = ipv4Settings
        
        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                os_log("Failed to set settings: %{public}@", log: .default, type: .error, error.localizedDescription)
                completionHandler(error)
            } else {
                os_log("Tunnel started. HTTP: %d, SOCKS: %d", log: .default, type: .info, self.httpPort, self.socksPort)
                completionHandler(nil)
            }
        }
    }
    
    private func startHTTPListener() throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: self.httpPort))
        
        listener.newConnectionHandler = { [weak self] connection in
            self?.httpProxy.handleConnection(connection)
        }
        listener.start(queue: .global())
        self.httpListener = listener
    }

    private func startSOCKSListener() throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: self.socksPort))
        
        listener.newConnectionHandler = { [weak self] connection in
            self?.socksProxy.handleConnection(connection)
        }
        listener.start(queue: .global())
        self.socksListener = listener
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        httpListener?.cancel()
        socksListener?.cancel()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle rule updates from App
        if let message = String(data: messageData, encoding: .utf8) {
            os_log("Received message from App: %{public}@", log: .default, type: .info, message)
            
            if message == "reload_rules" {
                // Reload rules from shared container
                let ruleManager = RuleManager()
                ruleManager.loadRules()
                os_log("Rules reloaded", log: .default, type: .info)
                
                completionHandler?("OK".data(using: .utf8))
            } else {
                completionHandler?(nil)
            }
        } else {
            completionHandler?(nil)
        }
    }
}
