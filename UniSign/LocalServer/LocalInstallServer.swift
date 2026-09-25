import Foundation
import UIKit
import Network

/// Lightweight embedded HTTP server to serve the signed IPA and manifest.plist
/// for local 1-click installation via itms-services protocol
public class LocalInstallServer {
    public static let shared = LocalInstallServer()
    
    private var listener: NWListener?
    public private(set) var isRunning: Bool = false
    public var port: UInt16 = 8080
    
    private var currentIPAURL: URL?
    private var currentBundleID: String = "com.unisign.signedapp"
    private var currentVersion: String = "1.0.0"
    private var currentTitle: String = "SignedApp"
    
    public enum ServerError: LocalizedError {
        case failedToBindPort
        case fileNotFound
        
        public var errorDescription: String? {
            switch self {
            case .failedToBindPort: return "Unable to bind local HTTP server to port \(LocalInstallServer.shared.port)."
            case .fileNotFound: return "IPA file to serve was not found."
            }
        }
    }
    
    /// Starts serving the specified IPA for local installation
    public func startServing(
        ipaURL: URL,
        bundleID: String,
        version: String,
        title: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        self.currentIPAURL = ipaURL
        self.currentBundleID = bundleID
        self.currentVersion = version
        self.currentTitle = title
        
        if isRunning {
            let manifestInstallURL = URL(string: "itms-services://?action=download-manifest&url=http://127.0.0.1:\(port)/manifest.plist")!
            completion(.success(manifestInstallURL))
            return
        }
        
        do {
            let tcpOptions = NWProtocolTCP.Options()
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.allowLocalEndpointReuse = true
            
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                throw ServerError.failedToBindPort
            }
            
            listener = try NWListener(using: params, on: nwPort)
            listener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isRunning = true
                    let installURL = URL(string: "itms-services://?action=download-manifest&url=http://127.0.0.1:\(self.port)/manifest.plist")!
                    completion(.success(installURL))
                case .failed(let err):
                    self.isRunning = false
                    completion(.failure(err))
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
        } catch {
            completion(.failure(error))
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, _ in
            guard let self = self, let content = content,
                  let requestStr = String(data: content, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            let firstLine = requestStr.components(separatedBy: "\r\n").first ?? ""
            let parts = firstLine.components(separatedBy: " ")
            let path = parts.count > 1 ? parts[1] : "/"
            
            if path.contains("manifest.plist") {
                let manifest = self.generateManifestXML()
                let response = "HTTP/1.1 200 OK\r\nContent-Type: application/xml\r\nContent-Length: \(manifest.utf8.count)\r\nConnection: close\r\n\r\n\(manifest)"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            } else if path.contains("app.ipa") {
                guard let ipaURL = self.currentIPAURL, let ipaData = try? Data(contentsOf: ipaURL) else {
                    let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
                    connection.send(content: notFound.data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
                    return
                }
                
                let header = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: \(ipaData.count)\r\nConnection: close\r\n\r\n"
                var fullData = header.data(using: .utf8)!
                fullData.append(ipaData)
                
                connection.send(content: fullData, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            } else {
                let ok = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nUniSign Ready"
                connection.send(content: ok.data(using: .utf8), completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
    }
    
    private func generateManifestXML() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>items</key>
            <array>
                <dict>
                    <key>assets</key>
                    <array>
                        <dict>
                            <key>kind</key>
                            <string>software-package</string>
                            <key>url</key>
                            <string>http://127.0.0.1:\(port)/app.ipa</string>
                        </dict>
                    </array>
                    <key>metadata</key>
                    <dict>
                        <key>bundle-identifier</key>
                        <string>\(currentBundleID)</string>
                        <key>bundle-version</key>
                        <string>\(currentVersion)</string>
                        <key>kind</key>
                        <string>software</string>
                        <key>title</key>
                        <string>\(currentTitle)</string>
                    </dict>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }
}
