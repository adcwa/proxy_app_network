import Foundation
import Network

public struct ConnectionStats {
    public var bytesSent: Int64 = 0
    public var bytesReceived: Int64 = 0
    public let startTime: Date = Date()
}

public class ProxyConnection {
    public let id: UUID
    public let sourceApp: String?
    public let targetHost: String
    public let targetPort: Int
    public let rule: RuleAction
    public var stats: ConnectionStats
    public var tunnel: NWConnection?
    
    public init(sourceApp: String?, targetHost: String, targetPort: Int, rule: RuleAction) {
        self.id = UUID()
        self.sourceApp = sourceApp
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.rule = rule
        self.stats = ConnectionStats()
    }
}

public class ConnectionManager {
    public static let shared = ConnectionManager()
    
    private var activeConnections: [UUID: ProxyConnection] = [:]
    private let queue = DispatchQueue(label: "com.proxyApp.connectionManager")
    
    public func track(connection: ProxyConnection) {
        queue.async {
            self.activeConnections[connection.id] = connection
        }
    }
    
    public func remove(id: UUID) {
        queue.async {
            self.activeConnections.removeValue(forKey: id)
        }
    }
    
    public func updateStats(id: UUID, sent: Int64, received: Int64) {
        queue.async {
            guard let conn = self.activeConnections[id] else { return }
            conn.stats.bytesSent += sent
            conn.stats.bytesReceived += received
            self.saveState() // Naive persistence on every update (optimize in prod)
        }
    }
    
    public func getAllConnections() -> [ProxyConnection] {
        return queue.sync {
            Array(activeConnections.values)
        }
    }
    
    private func saveState() {
        // Debounce? For MVP, just write.
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyApp.network")?.appendingPathComponent("connections.json") else { return }
        
        let connections = activeConnections.values.map { conn in
             // Simplified struct for JSON
             return ConnectionSnapshot(
                id: conn.id,
                app: conn.sourceApp ?? "Unknown",
                host: conn.targetHost,
                port: conn.targetPort,
                type: "TCP", // TODO: Dynamic
                status: "Active"
             )
        }
        
        if let data = try? JSONEncoder().encode(connections) {
            try? data.write(to: url)
        }
    }
}

public struct ConnectionSnapshot: Codable, Identifiable {
    public let id: UUID
    public let app: String
    public let host: String
    public let port: Int
    public let type: String
    public let status: String
}
