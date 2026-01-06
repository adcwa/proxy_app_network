import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager = ExtensionManager.shared
    @State private var socksHost: String = "127.0.0.1"
    @State private var socksPort: String = "1080"
    @State private var showTroubleshooting = false
    
    var body: some View {
        Form {
            Section(header: Text("Default Proxy")) {
                TextField("SOCKS5 Host", text: $socksHost)
                TextField("Port", text: $socksPort)
            }
            
            Section(header: Text("System Extension")) {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(statusText)
                        .foregroundColor(statusColor)
                        .fontWeight(.bold)
                }
                
                if let error = manager.lastError {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .font(.footnote)
                        
                        if error.contains("NEVPNErrorDomain") || manager.status == .invalid {
                            Button("Show Troubleshooting") {
                                showTroubleshooting = true
                            }
                            .font(.caption)
                        }
                    }
                }
                
                Button("Install Profile / Initialize") {
                    manager.installProfile()
                }
                
                Button("Start Proxy") {
                    manager.startExtension()
                }
                .disabled(manager.status == .connected || manager.status == .connecting)
                
                Button("Stop Proxy") {
                    manager.stopExtension()
                }
                .disabled(manager.status == .disconnected || manager.status == .invalid)
            }
            
            if showTroubleshooting {
                Section(header: Text("Troubleshooting")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Network Extension Setup Required")
                            .font(.headline)
                        
                        Text("This app requires a System Extension to function. The DMG build doesn't include proper Extension packaging.")
                            .font(.caption)
                        
                        Text("To use this app:")
                            .font(.subheadline)
                            .padding(.top, 5)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("1. Build with Xcode:")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("   swift package generate-xcodeproj")
                                .font(.system(.caption, design: .monospaced))
                            Text("   Open in Xcode and build")
                                .font(.caption)
                            
                            Text("2. Or use command line:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.top, 5)
                            Text("   swift run ProxyApp")
                                .font(.system(.caption, design: .monospaced))
                            
                            Text("3. Grant permissions:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.top, 5)
                            Text("   System Preferences → Privacy & Security")
                                .font(.caption)
                            Text("   Allow 'ProxyApp' Network Extension")
                                .font(.caption)
                        }
                        .padding(.leading, 10)
                        
                        Button("Close") {
                            showTroubleshooting = false
                        }
                        .padding(.top, 10)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: 600)
    }
    
    var statusText: String {
        switch manager.status {
        case .invalid: return "Invalid"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reasserting: return "Reasserting..."
        case .disconnecting: return "Disconnecting..."
        @unknown default: return "Unknown"
        }
    }
    
    var statusColor: Color {
        switch manager.status {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        case .disconnecting: return .yellow
        case .disconnected, .invalid: return .gray
        @unknown default: return .gray
        }
    }
}
