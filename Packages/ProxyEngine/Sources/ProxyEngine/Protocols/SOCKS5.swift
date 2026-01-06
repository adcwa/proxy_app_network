import Foundation
import Network
import os.log

public class SOCKS5Proxy {
    private let logger = Logger(subsystem: "com.proxyApp.engine", category: "SOCKS5")
    
    public init() {}
    
    public func handleConnection(_ connection: NWConnection) {
        // Start state machine
        connection.start(queue: .global())
        processHandshake(connection)
    }
    
    private func processHandshake(_ connection: NWConnection) {
        // Read version (1 byte) + nmethods (1 byte)
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] content, _, isComplete, error in
            guard let self = self, let data = content, error == nil, !isComplete else {
                return
            }
            
            let version = data[0]
            let nmethods = Int(data[1])
            
            guard version == 0x05 else {
                self.logger.error("Invalid SOCKS version: \(version)")
                connection.cancel()
                return
            }
            
            // Read methods
            connection.receive(minimumIncompleteLength: nmethods, maximumLength: nmethods) { [weak self] content, _, isComplete, error in
                guard let self = self, let _ = content, error == nil else { return }
                
                // Reply: Version 5, Method 0 (No Auth)
                let response = Data([0x05, 0x00])
                connection.send(content: response, completion: .contentProcessed { error in
                    if error == nil {
                        self.processRequest(connection)
                    }
                })
            }
        }
    }
    
    private func processRequest(_ connection: NWConnection) {
        // Read Request Header: VER CMD RSV ATYP [ADDR] PORT
        // Min length: 4 byte header + 1 byte len + 1 byte addr + 2 byte port = 8 (approx)
        // We'll read first 4 bytes to check command and type
        
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] content, _, isComplete, error in
            guard let self = self, let data = content, error == nil else { return }
            
            let version = data[0]
            let command = data[1] // 0x01: Connect
            let addressType = data[3]
            
            guard version == 0x05, command == 0x01 else {
                self.logger.error("Unsupported command: \(command)")
                connection.cancel()
                return
            }
            
            self.readAddress(connection, type: addressType)
        }
    }
    
    private func readAddress(_ connection: NWConnection, type: UInt8) {
        switch type {
        case 0x01: // IPv4
            connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, _ in
                guard let self = self, let ipData = data else { return }
                self.readPort(connection, address: ipData.map { String($0) }.joined(separator: "."))
            }
        case 0x03: // Domain
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] lenData, _, _, _ in
                guard let self = self, let len = lenData?.first else { return }
                connection.receive(minimumIncompleteLength: Int(len), maximumLength: Int(len)) { [weak self] hostData, _, _, _ in
                    guard let self = self, let hostVal = hostData, let hostStr = String(data: hostVal, encoding: .utf8) else { return }
                    self.readPort(connection, address: hostStr)
                }
            }
        case 0x04: // IPv6
             connection.receive(minimumIncompleteLength: 16, maximumLength: 16) { [weak self] data, _, _, _ in
                guard let self = self, let _ = data else { return }
                self.readPort(connection, address: "IPv6-Not-Supported-Yet")
            }
        default:
            connection.cancel()
        }
    }
    
    private func readPort(_ connection: NWConnection, address: String) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, _ in
            guard let self = self, let portData = data else { return }
            let port = (UInt16(portData[0]) << 8) + UInt16(portData[1])
            
            self.logger.info("SOCKS5 Request: \(address):\(port)")
            self.handleProxyLogic(client: connection, targetHost: address, targetPort: Int(port))
        }
    }
    
    private func handleProxyLogic(client: NWConnection, targetHost: String, targetPort: Int) {
        let ruleManager = RuleManager()
        let action = ruleManager.match(appBundleId: nil, targetHost: targetHost)
        
        // Reply success (0x00) - we always reply success first, then handle connection
        let success = Data([0x05, 0x00, 0x00, 0x01, 0,0,0,0, 0,0])
        client.send(content: success, completion: .contentProcessed { [weak self] error in
            guard let self = self, error == nil else { return }
            
            switch action {
            case .direct:
                // Direct connection
                self.connectDirect(client: client, host: targetHost, port: targetPort, rule: action)
                
            case .proxy(let proxyHost, let proxyPort, let proxyType):
                // Connect through proxy
                switch proxyType {
                case .socks5:
                    self.connectThroughSOCKS5(client: client, proxyHost: proxyHost, proxyPort: proxyPort, targetHost: targetHost, targetPort: targetPort, rule: action)
                case .http:
                    self.connectThroughHTTP(client: client, proxyHost: proxyHost, proxyPort: proxyPort, targetHost: targetHost, targetPort: targetPort, rule: action)
                }
            }
        })
    }
    
    private func connectDirect(client: NWConnection, host: String, port: Int, rule: RuleAction) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let remote = NWConnection(to: endpoint, using: .tcp)
        
        remote.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.pipe(from: client, to: remote)
                self?.pipe(from: remote, to: client)
            case .failed(let err):
                self?.logger.error("Direct connection failed: \(err.localizedDescription)")
                client.cancel()
            default: break
            }
        }
        remote.start(queue: .global())
        
        let stats = ProxyConnection(sourceApp: "Unknown", targetHost: host, targetPort: port, rule: rule)
        ConnectionManager.shared.track(connection: stats)
    }
    
    private func connectThroughSOCKS5(client: NWConnection, proxyHost: String, proxyPort: Int, targetHost: String, targetPort: Int, rule: RuleAction) {
        // Connect to SOCKS5 proxy server
        let proxyEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(proxyHost), port: NWEndpoint.Port(integerLiteral: UInt16(proxyPort)))
        let proxyConnection = NWConnection(to: proxyEndpoint, using: .tcp)
        
        proxyConnection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                // Send SOCKS5 handshake to remote proxy
                let handshake = Data([0x05, 0x01, 0x00]) // Version 5, 1 method, No Auth
                proxyConnection.send(content: handshake, completion: .contentProcessed { _ in
                    // Read handshake response
                    proxyConnection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, _, _ in
                        guard let response = data, response.count == 2, response[1] == 0x00 else {
                            self.logger.error("SOCKS5 proxy handshake failed")
                            client.cancel()
                            proxyConnection.cancel()
                            return
                        }
                        
                        // Send CONNECT request
                        self.sendSOCKS5ConnectRequest(to: proxyConnection, targetHost: targetHost, targetPort: targetPort) {
                            // Start piping
                            self.pipe(from: client, to: proxyConnection)
                            self.pipe(from: proxyConnection, to: client)
                        }
                    }
                })
            case .failed(let err):
                self.logger.error("SOCKS5 proxy connection failed: \(err.localizedDescription)")
                client.cancel()
            default: break
            }
        }
        proxyConnection.start(queue: .global())
        
        let stats = ProxyConnection(sourceApp: "Unknown", targetHost: targetHost, targetPort: targetPort, rule: rule)
        ConnectionManager.shared.track(connection: stats)
    }
    
    private func sendSOCKS5ConnectRequest(to proxy: NWConnection, targetHost: String, targetPort: Int, completion: @escaping () -> Void) {
        var request = Data([0x05, 0x01, 0x00]) // VER CMD RSV
        
        // ATYP + Address
        if let _ = IPv4Address(targetHost) {
            // IPv4
            request.append(0x01)
            let parts = targetHost.split(separator: ".").compactMap { UInt8($0) }
            request.append(contentsOf: parts)
        } else {
            // Domain
            request.append(0x03)
            request.append(UInt8(targetHost.count))
            request.append(contentsOf: targetHost.utf8)
        }
        
        // Port
        let portBytes = withUnsafeBytes(of: UInt16(targetPort).bigEndian) { Data($0) }
        request.append(contentsOf: portBytes)
        
        proxy.send(content: request, completion: .contentProcessed { _ in
            // Read response
            proxy.receive(minimumIncompleteLength: 10, maximumLength: 256) { data, _, _, _ in
                guard let response = data, response.count >= 2, response[1] == 0x00 else {
                    return
                }
                completion()
            }
        })
    }
    
    private func connectThroughHTTP(client: NWConnection, proxyHost: String, proxyPort: Int, targetHost: String, targetPort: Int, rule: RuleAction) {
        // Connect to HTTP proxy server
        let proxyEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(proxyHost), port: NWEndpoint.Port(integerLiteral: UInt16(proxyPort)))
        let proxyConnection = NWConnection(to: proxyEndpoint, using: .tcp)
        
        proxyConnection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                // Send HTTP CONNECT request
                let connectRequest = "CONNECT \(targetHost):\(targetPort) HTTP/1.1\r\nHost: \(targetHost):\(targetPort)\r\n\r\n"
                proxyConnection.send(content: connectRequest.data(using: .utf8), completion: .contentProcessed { _ in
                    // Read HTTP response
                    proxyConnection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                        guard let response = data, let responseStr = String(data: response, encoding: .utf8),
                              responseStr.contains("200") else {
                            self.logger.error("HTTP proxy CONNECT failed")
                            client.cancel()
                            proxyConnection.cancel()
                            return
                        }
                        
                        // Start piping
                        self.pipe(from: client, to: proxyConnection)
                        self.pipe(from: proxyConnection, to: client)
                    }
                })
            case .failed(let err):
                self.logger.error("HTTP proxy connection failed: \(err.localizedDescription)")
                client.cancel()
            default: break
            }
        }
        proxyConnection.start(queue: .global())
        
        let stats = ProxyConnection(sourceApp: "Unknown", targetHost: targetHost, targetPort: targetPort, rule: rule)
        ConnectionManager.shared.track(connection: stats)
    }
    
    private func pipe(from source: NWConnection, to dest: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                 dest.send(content: data, completion: .contentProcessed { _ in
                     // Loop
                     self?.pipe(from: source, to: dest)
                 })
            } else if isComplete || error != nil {
                source.cancel()
                dest.cancel()
            }
        }
    }
}
