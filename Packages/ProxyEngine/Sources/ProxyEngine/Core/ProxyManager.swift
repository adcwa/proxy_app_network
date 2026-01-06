import Foundation

/// Represents a proxy server configuration
public struct ProxyServer: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var type: ProxyType
    public var host: String
    public var port: Int
    public var username: String?
    public var password: String?
    public var enabled: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        type: ProxyType,
        host: String,
        port: Int,
        username: String? = nil,
        password: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.enabled = enabled
    }
}

/// Manages proxy server configurations
public class ProxyManager {
    public static let shared = ProxyManager()
    
    private var proxies: [ProxyServer] = []
    
    private init() {
        loadProxies()
    }
    
    public func add(proxy: ProxyServer) {
        proxies.append(proxy)
        saveProxies()
    }
    
    public func update(proxy: ProxyServer) {
        if let index = proxies.firstIndex(where: { $0.id == proxy.id }) {
            proxies[index] = proxy
            saveProxies()
        }
    }
    
    public func delete(id: UUID) {
        proxies.removeAll { $0.id == id }
        saveProxies()
    }
    
    public func getProxies() -> [ProxyServer] {
        return proxies
    }
    
    public func getProxy(id: UUID) -> ProxyServer? {
        return proxies.first { $0.id == id }
    }
    
    private var proxiesURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyApp.network")?
            .appendingPathComponent("proxies.json")
    }
    
    public func loadProxies() {
        guard let url = proxiesURL, let data = try? Data(contentsOf: url) else { return }
        if let loaded = try? JSONDecoder().decode([ProxyServer].self, from: data) {
            self.proxies = loaded
        }
    }
    
    private func saveProxies() {
        guard let url = proxiesURL else { return }
        if let data = try? JSONEncoder().encode(proxies) {
            try? data.write(to: url)
        }
    }
}
