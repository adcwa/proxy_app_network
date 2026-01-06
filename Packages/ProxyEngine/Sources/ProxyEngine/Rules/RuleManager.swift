import Foundation

public enum RuleType: Codable {
    case domain(String) // e.g., "*.google.com"
    case ip(String)     // e.g., "192.168.1.0/24"
    case app(String)    // e.g., "com.apple.safari"
    case all
}

public enum RuleAction: Codable {
    case direct
    case proxy(host: String, port: Int, type: ProxyType)
}

public enum ProxyType: Codable {
    case socks5
    case http
}

public struct Rule: Codable, Identifiable {
    public let id: UUID
    public let type: RuleType
    public let action: RuleAction
    
    public init(type: RuleType, action: RuleAction) {
        self.id = UUID()
        self.type = type
        self.action = action
    }
}

public class RuleManager {
    private var rules: [Rule] = []
    
    public init() {
        loadRules()
    }
    
    public func add(rule: Rule) {
        rules.append(rule)
        saveRules()
    }
    
    public func getRules() -> [Rule] {
        return rules
    }
    
    public func clear() {
        rules.removeAll()
        saveRules()
    }
    
    private var rulesURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyApp.network")?.appendingPathComponent("rules.json")
    }
    
    public func loadRules() {
        guard let url = rulesURL, let data = try? Data(contentsOf: url) else { return }
        if let loaded = try? JSONDecoder().decode([Rule].self, from: data) {
            self.rules = loaded
        }
    }
    
    private func saveRules() {
        guard let url = rulesURL else { return }
        if let data = try? JSONEncoder().encode(rules) {
            try? data.write(to: url)
        }
    }
    
    /// Matches a connection request against the rules
    /// - Parameters:
    ///   - appBundleId: The bundle ID of the source application
    ///   - targetHost: The destination hostname or IP
    /// - Returns: The action to take (Direct or Proxy)
    public func match(appBundleId: String?, targetHost: String) -> RuleAction {
        for rule in rules {
            if matches(rule: rule, appBundleId: appBundleId, targetHost: targetHost) {
                return rule.action
            }
        }
        return .direct // Default to direct if no rule matches
    }
    
    private func matches(rule: Rule, appBundleId: String?, targetHost: String) -> Bool {
        switch rule.type {
        case .all:
            return true
            
        case .app(let appPattern):
            guard let bundleId = appBundleId else { return false }
            return bundleId.localizedCaseInsensitiveContains(appPattern) // Simplified matching
            
        case .domain(let domainPattern):
            return matchesDomain(targetHost, pattern: domainPattern)
            
        case .ip(let ipPattern):
            return matchesIP(targetHost, pattern: ipPattern)
        }
    }
    
    private func matchesDomain(_ host: String, pattern: String) -> Bool {
        // Wildcard matching: *.example.com matches sub.example.com
        if pattern.starts(with: "*.") {
            let suffix = String(pattern.dropFirst(2))
            return host.hasSuffix(suffix) || host == suffix
        }
        // Exact match
        return host == pattern
    }
    
    private func matchesIP(_ host: String, pattern: String) -> Bool {
        // Check if pattern is CIDR notation (e.g., 192.168.0.0/16)
        if pattern.contains("/") {
            return matchesCIDR(host, cidr: pattern)
        }
        // Exact IP match
        return host == pattern
    }
    
    private func matchesCIDR(_ ip: String, cidr: String) -> Bool {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2,
              let prefixLength = Int(parts[1]),
              prefixLength >= 0 && prefixLength <= 32 else {
            return false
        }
        
        let networkIP = String(parts[0])
        
        guard let ipInt = ipToInt(ip),
              let networkInt = ipToInt(networkIP) else {
            return false
        }
        
        // Create subnet mask
        let mask: UInt32 = prefixLength == 0 ? 0 : ~UInt32(0) << (32 - prefixLength)
        
        return (ipInt & mask) == (networkInt & mask)
    }
    
    private func ipToInt(_ ip: String) -> UInt32? {
        let octets = ip.split(separator: ".").compactMap { UInt32($0) }
        guard octets.count == 4, octets.allSatisfy({ $0 <= 255 }) else {
            return nil
        }
        return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3]
    }
}
