import SwiftUI

import ProxyEngine

struct ConnectionListView: View {
    @State private var connections: [ConnectionSnapshot] = []
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Active Connections")
                .font(.headline)
                .padding(.bottom, 5)
            
            if connections.isEmpty {
                VStack {
                    Spacer()
                    Text("No Active Connections")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    Text("Start the proxy to see connections here")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            } else {
                Table(connections) {
                    TableColumn("Application", value: \.app)
                    TableColumn("Host", value: \.host)
                    TableColumn("Port") { item in Text("\(item.port)") }
                    TableColumn("Type", value: \.type)
                    TableColumn("Status", value: \.status)
                }
            }
        }
        .padding()
        .onReceive(timer) { _ in
            loadConnections()
        }
        .onAppear {
            loadConnections()
        }
    }
    
    private func loadConnections() {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyApp.network")?.appendingPathComponent("connections.json") else { return }
        
        if let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode([ConnectionSnapshot].self, from: data) {
            self.connections = loaded
        }
    }
}
