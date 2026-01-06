import SwiftUI

struct ConnectionItem: Identifiable {
    let id = UUID()
    let app: String
    let host: String
    let port: Int
    let type: String
    let status: String
}

struct ConnectionListView: View {
    // Mock data for MVP display
    @State private var connections: [ConnectionItem] = [
        ConnectionItem(app: "Safari", host: "google.com", port: 443, type: "HTTPS", status: "Active"),
        ConnectionItem(app: "Slack", host: "slack.com", port: 443, type: "Direct", status: "Active")
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Active Connections")
                .font(.headline)
                .padding(.bottom, 5)
            
            Table(connections) {
                TableColumn("Application", value: \.app)
                TableColumn("Host", value: \.host)
                TableColumn("Port") { item in Text("\(item.port)") }
                TableColumn("Type", value: \.type)
                TableColumn("Status", value: \.status)
            }
        }
        .padding()
    }
}
