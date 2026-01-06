import SwiftUI

struct SettingsView: View {
    @State private var socksHost: String = "127.0.0.1"
    @State private var socksPort: String = "1080"
    
    var body: some View {
        Form {
            Section(header: Text("Default Proxy")) {
                TextField("SOCKS5 Host", text: $socksHost)
                TextField("Port", text: $socksPort)
            }
            
            Section(header: Text("System Extension")) {
                Button("Install Extension") {
                    // Call ExtensionManager to install
                }
                Button("Start Proxy") {
                    // Call ExtensionManager to start
                }
                Button("Stop Proxy") {
                    // Call ExtensionManager to stop
                }
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }
}
