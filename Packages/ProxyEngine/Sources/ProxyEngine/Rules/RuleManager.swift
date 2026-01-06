import Foundation

public enum RuleType {
    case domain(String) // e.g., "*.google.com"
    case ip(String)     // e.g., "192.168.1.0/24"
    case app(String)    // e.g., "com.apple.safari"
    case all
}

public enum RuleAction {
    case direct
    case proxy(host: String, port: Int, type: ProxyType)
}

public enum ProxyType {
    case socks5
    case http
}

public struct Rule {
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
    
    public init() {}
    
    public func add(rule: Rule) {
        rules.append(rule)
    }
    
    public func clear() {
        rules.removeAll()
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
            // Simple wildcard matching: *.example.com matches sub.example.com
            if domainPattern.starts(with: "*.") {
                let suffix = String(domainPattern.dropFirst(2))
                return targetHost.hasSuffix(suffix) || targetHost == suffix
            }
            return targetHost == domainPattern
            
        case .ip(let ipPattern):
            // TODO: CIDR matching
            return targetHost.hasPrefix(ipPattern)
        }
    }
}
