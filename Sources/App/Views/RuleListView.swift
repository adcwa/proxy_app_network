import SwiftUI

struct RuleItem: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let action: String
}

struct RuleListView: View {
    @State private var rules: [RuleItem] = [
        RuleItem(name: "Google Services", value: "*.google.com", action: "Proxy (Default)"),
        RuleItem(name: "Local LAN", value: "192.168.0.0/16", action: "Direct")
    ]
    
    var body: some View {
        VStack {
            HStack {
                Text("Traffic Rules")
                    .font(.headline)
                Spacer()
                Button(action: { /* Add Rule */ }) {
                    Label("Add Rule", systemImage: "plus")
                }
            }
            .padding([.top, .horizontal])
            
            Table(rules) {
                TableColumn("Name", value: \.name)
                TableColumn("Pattern", value: \.value)
                TableColumn("Action", value: \.action)
            }
        }
        .padding()
    }
}
