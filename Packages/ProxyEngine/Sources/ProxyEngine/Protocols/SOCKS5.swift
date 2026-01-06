import Foundation
import Network

public enum SOCKS5Error: Error {
    case invalidVersion
    case noAcceptableMethods
    case authenticationFailed
    case invalidResponse
    case connectionFailed(UInt8)
}

public class SOCKS5Proxy {
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

    /// Performs the SOCKS5 handshake on the given connection
    /// - Parameters:
    ///   - connection: The established TCP connection to the proxy server
    ///   - targetHost: The final destination host
    ///   - targetPort: The final destination port
    ///   - completion: Callback when handshake is complete
    public func handshake(connection: NWConnection, targetHost: String, targetPort: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        // 1. Negotiation
        var methods: [UInt8] = [0x00] // No authentication
        if username != nil && password != nil {
            methods.append(0x02) // Username/Password
        }
        
        let version: UInt8 = 0x05
        let negotiationMsg = Data([version, UInt8(methods.count)] + methods)
        
        connection.send(content: negotiationMsg, completion: .contentProcessed { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.readNegotiationResponse(connection: connection, targetHost: targetHost, targetPort: targetPort, completion: completion)
        })
    }
    
    private func readNegotiationResponse(connection: NWConnection, targetHost: String, targetPort: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] content, _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = content, data.count >= 2, data[0] == 0x05 else {
                completion(.failure(SOCKS5Error.invalidVersion))
                return
            }
            
            let method = data[1]
            if method == 0x00 {
                self?.sendConnectRequest(connection: connection, targetHost: targetHost, targetPort: targetPort, completion: completion)
            } else if method == 0x02 {
                self?.performAuthentication(connection: connection, targetHost: targetHost, targetPort: targetPort, completion: completion)
            } else {
                completion(.failure(SOCKS5Error.noAcceptableMethods))
            }
        }
    }
    
    private func performAuthentication(connection: NWConnection, targetHost: String, targetPort: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = username, let pass = password, !user.isEmpty, !pass.isEmpty else {
             completion(.failure(SOCKS5Error.authenticationFailed))
             return
        }
        
        let userBytes = Array(user.utf8)
        let passBytes = Array(pass.utf8)
        
        // Ver(1) | Ulen(1) | User | Plen(1) | Pass
        var authData = Data([0x01, UInt8(userBytes.count)])
        authData.append(contentsOf: userBytes)
        authData.append(UInt8(passBytes.count))
        authData.append(contentsOf: passBytes)
        
        connection.send(content: authData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.readAuthResponse(connection: connection, targetHost: targetHost, targetPort: targetPort, completion: completion)
        })
    }
    
    private func readAuthResponse(connection: NWConnection, targetHost: String, targetPort: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] content, _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = content, data.count >= 2, data[1] == 0x00 else {
                completion(.failure(SOCKS5Error.authenticationFailed))
                return
            }
            // Auth success, proceed to connect
            self?.sendConnectRequest(connection: connection, targetHost: targetHost, targetPort: targetPort, completion: completion)
        }
    }
    
    private func sendConnectRequest(connection: NWConnection, targetHost: String, targetPort: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        // VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT
        //  1  |  1  | X'00' |  1   | Variable |    2
        
        var request = Data([0x05, 0x01, 0x00]) // VER=5, CMD=Connect, RSV=0
        
        if let ip = IPv4Address(targetHost) {
            request.append(0x01) // ATYP = IPv4
            request.append(ip.rawValue)
        } else if let ip = IPv6Address(targetHost) {
            request.append(0x04) // ATYP = IPv6
            request.append(ip.rawValue)
        } else {
            request.append(0x03) // ATYP = Domain
            let hostBytes = Array(targetHost.utf8)
            request.append(UInt8(hostBytes.count))
            request.append(contentsOf: hostBytes)
        }
        
        // Port (Big Endian)
        var portBigEndian = UInt16(targetPort).bigEndian
        let portData = Data(bytes: &portBigEndian, count: 2)
        request.append(portData)
        
        connection.send(content: request, completion: .contentProcessed { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.readConnectResponse(connection: connection, completion: completion)
        })
    }
    
    private func readConnectResponse(connection: NWConnection, completion: @escaping (Result<Void, Error>) -> Void) {
        // Read initial 4 bytes: VER | REP | RSV | ATYP
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { content, _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = content, data.count >= 4, data[0] == 0x05 else {
                completion(.failure(SOCKS5Error.invalidResponse))
                return
            }
            
            let rep = data[1]
            if rep != 0x00 {
                completion(.failure(SOCKS5Error.connectionFailed(rep)))
                return
            }
            
            // Success! The rest of the message depends on ATYP, but usually we just consume it.
            // Ideally we need to parse the bound address/port, but for transparent proxying we often just start forwarding.
            // Let's drain the rest of the header.
            let atyp = data[3]
            var lengthToRead = 0
            if atyp == 0x01 { lengthToRead = 4 + 2 } // IPv4 + Port
            else if atyp == 0x04 { lengthToRead = 16 + 2 } // IPv6 + Port
            else if atyp == 0x03 {
                // Determine length for domain. This implies we need to read 1 byte first for len.
                // For simplicity, we might assume we can read the rest just by reading.
                // But `receive` is tricky. Let's do a simple read for ATYP=3 case.
                // We'll just read "some" data to clear the buffer if possible.
                // But strictly, we should read the exact amount.
                
                // Let's implement a "Consumption" step for variable length domain if needed.
                // Since this is MVP, let's defer precise bound-address parsing unless needed.
                // Wait, if we don't read it, it will be part of the stream payload. We MUST read it.
            }
            
            if atyp == 0x03 {
                 // READ 1 byte for length
                 connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { lenContent, _, _, lenErr in
                      guard let lenData = lenContent, let len = lenData.first else {
                          completion(.failure(lenErr ?? SOCKS5Error.invalidResponse))
                          return
                      }
                      // Read Domain + Port
                      connection.receive(minimumIncompleteLength: Int(len) + 2, maximumLength: Int(len) + 2) { _, _, _, finalErr in
                          if let err = finalErr { completion(.failure(err)); return }
                          completion(.success(()))
                      }
                 }
            } else {
                 connection.receive(minimumIncompleteLength: lengthToRead, maximumLength: lengthToRead) { _, _, _, finalErr in
                      if let err = finalErr { completion(.failure(err)); return }
                      completion(.success(()))
                 }
            }
        }
    }
}
