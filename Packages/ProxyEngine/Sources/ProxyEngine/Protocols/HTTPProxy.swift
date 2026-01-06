import Foundation
import Network
import os.log

public class HTTPProxy {
    private let logger = Logger(subsystem: "com.proxyApp.engine", category: "HTTP")
    
    public init() {}
    
    public func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        readRequest(connection)
    }
    
    private func readRequest(_ connection: NWConnection) {
        // Read until double CRLF to get headers
        // Simple implementation: Read 4KB chunk and parse
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self, let data = content, !data.isEmpty, error == nil else {
                connection.cancel()
                return
            }
            
            guard let requestString = String(data: data, encoding: .utf8) else { return }
            let lines = requestString.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else { return }
            
            let parts = requestLine.components(separatedBy: " ")
            guard parts.count >= 2 else { return }
            
            let method = parts[0]
            let url = parts[1]
            
            if method == "CONNECT" {
                self.handleHTTPSConnect(connection: connection, target: url)
            } else if method == "GET" && url.contains("/proxy.pac") {
                self.servePAC(connection: connection)
            } else {
                self.handleHTTPRequest(connection: connection, requestData: data, targetUrl: url)
            }
        }
    }
    
    private func servePAC(connection: NWConnection) {
        let pacContent = """
        function FindProxyForURL(url, host) {
            return "SOCKS5 127.0.0.1:9091; SOCKS 127.0.0.1:9091; HTTP 127.0.0.1:9090; HTTPS 127.0.0.1:9090; DIRECT";
        }
        """
        
        let response = "HTTP/1.1 200 OK\r\nContent-Type: application/x-ns-proxy-autoconfig\r\nContent-Length: \(pacContent.utf8.count)\r\nConnection: close\r\n\r\n\(pacContent)"
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func handleHTTPSConnect(connection: NWConnection, target: String) {
        // host:port
        let hostParts = target.components(separatedBy: ":")
        guard let host = hostParts.first, let portStr = hostParts.last, let port = Int(portStr) else { return }
        
        self.logger.info("HTTPS CONNECT: \(host):\(port)")
        
        // TODO: Rule Match
        
        // Connect to remote
        self.connectRemote(client: connection, host: host, port: port) { success in
            if success {
                // Reply 200 OK
                let response = "HTTP/1.1 200 Connection Established\r\n\r\n".data(using: .utf8)!
                connection.send(content: response, completion: .contentProcessed { error in
                    // Tunnel established, hand over to pipe
                    // Note: pipe logic is shared, ideally refactor to common Utils
                })
            }
        }
    }
    
    private func handleHTTPRequest(connection: NWConnection, requestData: Data, targetUrl: String) {
        // Parse Host from URL or Headers
        guard let urlObj = URL(string: targetUrl), let host = urlObj.host else { return }
        let port = urlObj.port ?? 80
        
        self.logger.info("HTTP Request: \(host):\(port)")
        
        // Connect and forward payload
        self.connectRemote(client: connection, host: host, port: port) { success in
            if success {
                // Determine remote connection (stored where? For valid scoping we need to pass it)
                // This simple implementation flaw requires fixing: connectRemote needs to give back the connection
            }
        }
    }
    
    // Refactored Connect Remote to be cleaner
    private func connectRemote(client: NWConnection, host: String, port: Int, completion: @escaping (Bool) -> Void) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let remote = NWConnection(to: endpoint, using: .tcp)
        
        remote.stateUpdateHandler = { state in
            switch state {
            case .ready:
                completion(true)
                // If it was HTTPS Connect, we already sent 200 OK.
                // Now pipe.
                // We need to pass the 'remote' object out or manage it here.
                // For this quick impl, let's start piping here immediately?
                // But for HTTP, we need to send the ORIGINAL payload first if it wasn't CONNECT.
                
                self.pipe(from: client, to: remote)
                self.pipe(from: remote, to: client)
                
            case .failed(_):
                completion(false)
                client.cancel()
            default: break
            }
        }
        remote.start(queue: .global())
        
         // Track connection
        _ = UUID()
        let stats = ProxyConnection(sourceApp: "Unknown", targetHost: host, targetPort: port, rule: .direct)
        ConnectionManager.shared.track(connection: stats)
    }
    
    private func pipe(from source: NWConnection, to dest: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                 dest.send(content: data, completion: .contentProcessed { _ in
                     self?.pipe(from: source, to: dest)
                 })
            } else if isComplete || error != nil {
                source.cancel()
                dest.cancel()
            }
        }
    }
}
