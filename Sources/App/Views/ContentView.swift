import SwiftUI
// import ProxyEngine // In a real project, we'd import the shared package

struct ContentView: View {
    var body: some View {
        TabView {
            ConnectionListView()
                .tabItem {
                    Label("Connections", systemImage: "network")
                }
            
            RuleListView()
                .tabItem {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }
            
            ProxyListView()
                .tabItem {
                    Label("Proxies", systemImage: "server.rack")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
}
