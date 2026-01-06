import Foundation
import Network

public enum HTTPProxyError: Error {
    case invalidResponse
    case connectionRefused(Int)
}

public class HTTPProxy {
    public let host: String
    public let port: Int
    public let username: String?
    public let password: String?

    public init(host: String, port: Int, username: String? = nil, password: String? = nil) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }

    /// Performs HTTP CONNECT handshake
    public func handshake(connection: NWConnection, targetHost: String, targetPort: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        var request = "CONNECT \(targetHost):\(targetPort) HTTP/1.1\r\n"
        request += "Host: \(targetHost):\(targetPort)\r\n"
        
        if let user = username, let pass = password {
            let credentials = "\(user):\(pass)"
            if let data = credentials.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                request += "Proxy-Authorization: Basic \(base64)\r\n"
            }
        }
        
        request += "\r\n"
        
        guard let data = request.data(using: .utf8) else {
            completion(.failure(HTTPProxyError.invalidResponse))
            return
        }
        
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.readResponse(connection: connection, completion: completion)
        })
    }
    
    private func readResponse(connection: NWConnection, completion: @escaping (Result<Void, Error>) -> Void) {
        // Read until \r\n\r\n
        // This is tricky with NWConnection as it doesn't have "read until delimiter" easily.
        // For MVP, we'll read a chunk and look for 200 OK. 
        // A typical response is small: "HTTP/1.1 200 Connection Installed\r\n\r\n"
        
        connection.receive(minimumIncompleteLength: 10, maximumLength: 4096) { content, _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = content, let responseString = String(data: data, encoding: .utf8) else {
                completion(.failure(HTTPProxyError.invalidResponse))
                return
            }
            
            if responseString.contains(" 200 ") {
                // Verify we consumed the whole header. 
                // If the read didn't consume \r\n\r\n, we might have leftover header bytes.
                // In a robust implementation, we need a buffer to scan for \r\n\r\n.
                // For this MVP, we assume the first packet contains the full header.
                completion(.success(()))
            } else {
                // Try to parse status code
                // HTTP/1.1 403 Forbidden...
                completion(.failure(HTTPProxyError.connectionRefused(400))) // Simplified error
            }
        }
    }
}
