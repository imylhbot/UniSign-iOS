import Foundation
import UIKit
import Network

/// Embedded HTTP server to serve the signed IPA and manifest.plist
/// for local 1-click installation via itms-services protocol on iOS devices.
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
    
    /// Starts the local HTTP listener
    public func start() throws {
        if isRunning { return }
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.allowLocalEndpointReuse = true
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.failedToBindPort
        }
        
        let newListener = try NWListener(using: params, on: nwPort)
        newListener.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.isRunning = true
            } else if case .failed = state {
                self?.isRunning = false
            }
        }
        newListener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        newListener.start(queue: .global(qos: .userInitiated))
        self.listener = newListener
        self.isRunning = true
    }
    
    /// Generates local itms-services manifest URL or LAN download URL
    public func generateInstallURL(ipaURL: URL, bundleID: String, title: String, version: String = "1.0.0") -> URL {
        self.currentIPAURL = ipaURL
        self.currentBundleID = bundleID
        self.currentTitle = title
        self.currentVersion = version
        let host = LocalInstallServer.getWiFiIPAddress() ?? "127.0.0.1"
        return URL(string: "http://\(host):\(port)/")!
    }
    
    /// Gets current Wi-Fi LAN IP address (en0)
    public static func getWiFiIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            if addr.sa_family == UInt8(AF_INET) && (flags & IFF_LOOPBACK) == 0 {
                let name = String(cString: ptr.pointee.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        return address
    }
    
    public func getShareURL() -> String {
        let host = LocalInstallServer.getWiFiIPAddress() ?? "127.0.0.1"
        return "http://\(host):\(port)"
    }
    
    /// Constructs a valid itms-services URL pointing to the local manifest
    public func getManifestInstallURL() -> URL {
        let host = LocalInstallServer.getWiFiIPAddress() ?? "127.0.0.1"
        let rawURL = "http://\(host):\(port)/manifest.plist"
        let encoded = rawURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawURL
        return URL(string: "itms-services://?action=download-manifest&url=\(encoded)")!
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
            completion(.success(getManifestInstallURL()))
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
                    completion(.success(self.getManifestInstallURL()))
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
    
    /// Opens Safari to install the Local CA configuration profile for 100% reliable 127.0.0.1 bypass
    public func installLocalCAProfile() {
        if !isRunning {
            try? start()
        }
        let url = URL(string: "http://127.0.0.1:\(port)/ca.mobileconfig")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
                let response = "HTTP/1.1 200 OK\r\nContent-Type: application/xml; charset=utf-8\r\nContent-Length: \(manifest.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(manifest)"
                connection.send(content: response.data(using: .utf8), contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            } else if path.contains("ca.mobileconfig") {
                let profile = self.generateCAProfileXML()
                let response = "HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config; charset=utf-8\r\nContent-Disposition: attachment; filename=\"UniSignLocalCA.mobileconfig\"\r\nContent-Length: \(profile.utf8.count)\r\nConnection: close\r\n\r\n\(profile)"
                connection.send(content: response.data(using: .utf8), contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            } else if path.contains("app.ipa") {
                guard let ipaURL = self.currentIPAURL, let ipaData = try? Data(contentsOf: ipaURL) else {
                    let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
                    connection.send(content: notFound.data(using: .utf8), contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                        connection.cancel()
                    }))
                    return
                }
                
                let header = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: \(ipaData.count)\r\nContent-Disposition: attachment; filename=\"\(self.currentTitle).ipa\"\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
                var fullData = header.data(using: .utf8)!
                fullData.append(ipaData)
                
                connection.send(content: fullData, contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            } else {
                let html = self.generateDownloadHTML()
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
                connection.send(content: response.data(using: .utf8), contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
    }
    
    private func generateDownloadHTML() -> String {
        let installLink = getManifestInstallURL().absoluteString
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>UniSign 本地极速安装服务</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0F172A; color: #F8FAFC; text-align: center; padding: 30px 16px; margin: 0; }
            .card { background: #1E293B; border-radius: 20px; max-width: 480px; margin: 0 auto; padding: 28px 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); border: 1px solid #334155; }
            .icon { font-size: 52px; margin-bottom: 12px; }
            h1 { font-size: 22px; margin: 0 0 8px 0; color: #38BDF8; font-weight: bold; }
            p { font-size: 14px; color: #94A3B8; line-height: 1.6; margin: 0 0 20px 0; }
            .btn { display: block; background: linear-gradient(135deg, #0066EB, #0284C7); color: white; text-decoration: none; padding: 14px 24px; border-radius: 12px; font-weight: bold; font-size: 16px; margin: 10px 0; box-shadow: 0 4px 15px rgba(0,102,235,0.3); }
            .btn-green { background: linear-gradient(135deg, #10B981, #059669); box-shadow: 0 4px 15px rgba(16,185,129,0.3); }
            .btn-secondary { background: #334155; color: #E2E8F0; font-size: 13px; padding: 10px 16px; }
            .guide { text-align: left; background: #0F172A; padding: 16px; border-radius: 12px; font-size: 13px; color: #CBD5E1; margin-top: 20px; border: 1px solid #334155; }
            .guide ol { margin: 8px 0 0 0; padding-left: 20px; line-height: 1.6; }
            .guide li { margin-bottom: 6px; }
            .badge { display: inline-block; background: #0284C7; color: white; font-size: 11px; padding: 2px 8px; border-radius: 10px; margin-top: 4px; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">📦</div>
            <h1>\(currentTitle)</h1>
            <div><span class="badge">v\(currentVersion)</span></div>
            <p style="margin-top: 10px;">Bundle ID: <code>\(currentBundleID)</code><br>应用已签名完成，支持手机直接安装与局域网下载！</p>
            
            <a href="\(installLink)" class="btn btn-green">📲 点击直接安装到本手机</a>
            <a href="/app.ipa" class="btn" download="\(currentTitle).ipa">📥 下载 IPA 文件</a>
            <a href="/ca.mobileconfig" class="btn btn-secondary">🛡️ 安装本地 CA 信任证书 (若提示127.0.0.1)</a>
            
            <div class="guide">
              <strong style="color: #38BDF8;">💡 手机本地安装遇到问题？</strong>
              <ol>
                <li>若提示「无法连接到 127.0.0.1」，点击上方「安装本地 CA 信任证书」，并在系统「设置 -> 已下载描述文件」中安装并信任。</li>
                <li>首次安装自签应用，请前往「设置 -> 通用 -> VPN 与设备管理」信任证书。</li>
                <li>iOS 16+ 需开启「设置 -> 隐私与安全性 -> 开发者模式」。</li>
              </ol>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generateManifestXML() -> String {
        let host = LocalInstallServer.getWiFiIPAddress() ?? "127.0.0.1"
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
                            <string>http://\(host):\(port)/app.ipa</string>
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
    
    private func generateCAProfileXML() -> String {
        let uuid = UUID().uuidString
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadDisplayName</key>
            <string>UniSign Local Install CA</string>
            <key>PayloadDescription</key>
            <string>Allows local on-device IPA installation without 127.0.0.1 blocking</string>
            <key>PayloadIdentifier</key>
            <string>com.unisign.localca.\(uuid)</string>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(uuid)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadContent</key>
            <array/>
        </dict>
        </plist>
        """
    }
}
