import SwiftUI
import ProxyEngine

struct ProxyListView: View {
    @State private var proxies: [ProxyServer] = []
    @State private var showingAddProxy = false
    private let proxyManager = ProxyManager.shared
    
    var body: some View {
        VStack {
            HStack {
                Text("Proxy Servers")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddProxy = true }) {
                    Label("Add Proxy", systemImage: "plus")
                }
            }
            .padding([.top, .horizontal])
            
            if proxies.isEmpty {
                VStack {
                    Spacer()
                    Text("No Proxy Servers")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    Text("Add a proxy server to get started")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            } else {
                Table(proxies) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Type") { proxy in
                        Text(proxy.type == .socks5 ? "SOCKS5" : "HTTP")
                    }
                    TableColumn("Address") { proxy in
                        Text("\(proxy.host):\(proxy.port)")
                    }
                    TableColumn("Status") { proxy in
                        Text(proxy.enabled ? "Enabled" : "Disabled")
                            .foregroundColor(proxy.enabled ? .green : .gray)
                    }
                    TableColumn("Actions") { proxy in
                        HStack {
                            Button("Edit") {
                                // TODO: Edit proxy
                            }
                            .buttonStyle(.borderless)
                            
                            Button("Delete") {
                                proxyManager.delete(id: proxy.id)
                                loadProxies()
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            loadProxies()
        }
        .sheet(isPresented: $showingAddProxy) {
            AddProxyView(proxyManager: proxyManager, isPresented: $showingAddProxy, onAdd: loadProxies)
        }
    }
    
    private func loadProxies() {
        proxyManager.loadProxies()
        self.proxies = proxyManager.getProxies()
    }
}

struct AddProxyView: View {
    let proxyManager: ProxyManager
    @Binding var isPresented: Bool
    let onAdd: () -> Void
    
    @State private var name = ""
    @State private var type: ProxyType = .socks5
    @State private var host = ""
    @State private var port = "1080"
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Proxy Server")
                .font(.headline)
            
            Form {
                TextField("Name", text: $name)
                
                Picker("Type", selection: $type) {
                    Text("SOCKS5").tag(ProxyType.socks5)
                    Text("HTTP").tag(ProxyType.http)
                }
                
                TextField("Host", text: $host)
                TextField("Port", text: $port)
                
                Section(header: Text("Authentication (Optional)")) {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Add") {
                    let proxy = ProxyServer(
                        name: name,
                        type: type,
                        host: host,
                        port: Int(port) ?? 1080,
                        username: username.isEmpty ? nil : username,
                        password: password.isEmpty ? nil : password
                    )
                    proxyManager.add(proxy: proxy)
                    onAdd()
                    isPresented = false
                }
                .disabled(name.isEmpty || host.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}
