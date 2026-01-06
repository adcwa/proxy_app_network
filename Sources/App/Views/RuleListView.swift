import SwiftUI

import ProxyEngine

struct RuleListView: View {
    @State private var rules: [Rule] = []
    private let ruleManager = RuleManager()
    @State private var showingAddRule = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Traffic Rules")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
            }
            .padding([.top, .horizontal])
            
            Table(rules) {
                TableColumn("Type") { rule in Text("\(rule.type)") }
                // Naive string representation for MVP
                TableColumn("Action") { rule in Text("\(rule.action)") }
            }
        }
        .padding()
        .onAppear {
            loadRules()
        }
        .sheet(isPresented: $showingAddRule) {
            AddRuleView(ruleManager: ruleManager, isPresented: $showingAddRule, onAdd: loadRules)
        }
    }
    
    private func loadRules() {
        ruleManager.loadRules()
        self.rules = ruleManager.getRules()
        
        // Notify Extension to reload rules
        ExtensionManager.shared.sendRuleUpdate()
    }
}

// Simple Add Rule View
struct AddRuleView: View {
    let ruleManager: RuleManager
    @Binding var isPresented: Bool
    let onAdd: () -> Void
    
    @State private var ruleType: RuleTypeSelection = .domain
    @State private var pattern = ""
    @State private var action: RuleActionSelection = .direct
    @State private var selectedProxyId: UUID?
    @State private var availableProxies: [ProxyServer] = []
    
    enum RuleTypeSelection {
        case domain, ip, app
    }
    
    enum RuleActionSelection {
        case direct, proxy
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Rule")
                .font(.headline)
            
            Form {
                Picker("Rule Type", selection: $ruleType) {
                    Text("Domain").tag(RuleTypeSelection.domain)
                    Text("IP/CIDR").tag(RuleTypeSelection.ip)
                    Text("Application").tag(RuleTypeSelection.app)
                }
                
                TextField(placeholderText, text: $pattern)
                
                Picker("Action", selection: $action) {
                    Text("Direct").tag(RuleActionSelection.direct)
                    Text("Proxy").tag(RuleActionSelection.proxy)
                }
                
                if action == .proxy && !availableProxies.isEmpty {
                    Picker("Proxy Server", selection: $selectedProxyId) {
                        ForEach(availableProxies) { proxy in
                            Text(proxy.name).tag(proxy.id as UUID?)
                        }
                    }
                }
            }
            
            HStack {
                Button("Cancel") { isPresented = false }
                Button("Add") {
                    let ruleTypeEnum: RuleType
                    switch ruleType {
                    case .domain: ruleTypeEnum = .domain(pattern)
                    case .ip: ruleTypeEnum = .ip(pattern)
                    case .app: ruleTypeEnum = .app(pattern)
                    }
                    
                    let ruleAction: RuleAction
                    if action == .direct {
                        ruleAction = .direct
                    } else if let proxyId = selectedProxyId,
                              let proxy = availableProxies.first(where: { $0.id == proxyId }) {
                        ruleAction = .proxy(host: proxy.host, port: proxy.port, type: proxy.type)
                    } else {
                        ruleAction = .direct
                    }
                    
                    let rule = Rule(type: ruleTypeEnum, action: ruleAction)
                    ruleManager.add(rule: rule)
                    onAdd()
                    isPresented = false
                }
                .disabled(pattern.isEmpty || (action == .proxy && selectedProxyId == nil))
            }
        }
        .padding()
        .frame(width: 400, height: 350)
        .onAppear {
            availableProxies = ProxyManager.shared.getProxies()
            selectedProxyId = availableProxies.first?.id
        }
    }
    
    var placeholderText: String {
        switch ruleType {
        case .domain: return "e.g., *.google.com"
        case .ip: return "e.g., 192.168.0.0/16"
        case .app: return "e.g., com.apple.safari"
        }
    }
}
