import Foundation
import UIKit
import Network
import Security

/// Embedded HTTPS server to serve the signed IPA and manifest.plist
/// for local 1-click installation via itms-services protocol on iOS devices.
/// Supports genuine TLS with embedded local certificate for 100% reliable on-device install.
public class LocalInstallServer {
    public static let shared = LocalInstallServer()
    
    private var listener: NWListener?
    public private(set) var isRunning: Bool = false
    public var port: UInt16 = 8080
    
    private var currentIPAURL: URL?
    private var currentBundleID: String = "com.unisign.signedapp"
    private var currentVersion: String = "1.0.0"
    private var currentTitle: String = "SignedApp"
    
    // Valid 10-year Root CA Certificate (Base64 DER) for .mobileconfig
    private static let caCertBase64 = "MIIDNzCCAh+gAwIBAgIUXWIrB4ylX9eFqfewfVq9aE2vDi8wDQYJKoZIhvcNAQELBQAwQzEeMBwGA1UEAwwVVW5pU2lnbiBMb2NhbCBSb290IENBMRQwEgYDVQQKDAtVbmlTaWduIEFwcDELMAkGA1UEBhMCQ04wHhcNMjYwOTI0MTYxMTE0WhcNMzYwOTIyMTYxMTE0WjBDMR4wHAYDVQQDDBVVbmlTaWduIExvY2FsIFJvb3QgQ0ExFDASBgNVBAoMC1VuaVNpZ24gQXBwMQswCQYDVQQGEwJDTjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKIsEUZAcGnCvPp0nB50tpOsCFU0KWya4Xlnc3bKoDzllf/Op1O2iy9A9GCDydg6Q/sXLWRXZTaoaPd5xd4pQljYoAa4o718mCoaUPe3+YKpTRlAK5EtsLjX4oWRXRyEAU9nXhXPr5bGxd0Ae/f+AT6QsFg7GGHv2kGAsCmkpRt260mY/t4mOrB71solNK1zZgAh7jkd98iBGo2YoDnR3d7o4NXUfGqh4Id7atwaljV7Zw2bzEjirlCltG17Gwlcg/IILM9IScIrtQgj2b6IoByI7R/6mwopu3/j/TJJ/Za5MGsEQp5066niUsM163hAOgB0M6CEB9aqWE4HN/OnXOcCAwEAAaMjMCEwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAaYwDQYJKoZIhvcNAQELBQADggEBADdXlOlBt8nMLwy3liC6g+hBVSI5gdbF7RDumu3eDQkLBuGJ4CqTOAEAE3OdrAqawFhX4nqMlfm7gHPzxyTXbNRh5l+JKVkhfQpqzwgx9mEOJfYcpkLGAhAv/TNmWNsfnF7hR/g5QKtiN9qG8Oonja1Q4byj92Zazfv1MWSMaLcFQgaOqxIt73hHShy2B67sjuEDYospznHcDoDBoBxSr1LPNxS+aDV8XjYiclP4+ZWQezHgt/LBUOHH8YQYR0eKoiuqpi3Ttd9b7cnRDxFQgCXFrUFkiGj0kIMTLEm8Fvqydp9DrH86xlQK6Cu07SODcnhsOaxRorDGIejkt3o3pCY="
    
    // Server PKCS#12 (Base64 P12) signed by Root CA with password 'unisign'
    private static let serverP12Base64 = "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"
    
    public enum ServerError: LocalizedError {
        case failedToBindPort
        case fileNotFound
        
        public var errorDescription: String? {
            switch self {
            case .failedToBindPort: return "Unable to bind local HTTPS server to port \(LocalInstallServer.shared.port)."
            case .fileNotFound: return "IPA file to serve was not found."
            }
        }
    }
    
    /// Creates TLS parameters from the embedded P12 certificate
    private static func createTLSOptions() -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()
        guard let p12Data = Data(base64Encoded: serverP12Base64) else {
            return tlsOptions
        }
        let importOptions = [kSecImportExportPassphrase as String: "unisign"] as CFDictionary
        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, importOptions, &rawItems)
        if status == errSecSuccess,
           let items = rawItems as? [[String: Any]],
           let dict = items.first,
           let item = dict[kSecImportItemIdentity as String] {
            let clientIdentity = item as! SecIdentity
            if let secIdentity = sec_identity_create(clientIdentity) {
                sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, secIdentity)
            }
        }
        return tlsOptions
    }
    
    /// Starts the local HTTPS listener
    public func start() throws {
        if isRunning { return }
        let tcpOptions = NWProtocolTCP.Options()
        let tlsOptions = LocalInstallServer.createTLSOptions()
        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
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
        return "https://\(host):\(port)"
    }
    
    /// Constructs a valid itms-services URL pointing to the local HTTPS manifest
    public func getManifestInstallURL() -> URL {
        let host = "127.0.0.1"
        let rawURL = "https://\(host):\(port)/manifest.plist"
        let encoded = rawURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawURL
        return URL(string: "itms-services://?action=download-manifest&url=\(encoded)")!
    }
    
    /// Sets current IPA parameters and returns the local manifest install URL
    @discardableResult
    public func generateInstallURL(ipaURL: URL, bundleID: String, version: String = "1.0.0", title: String) -> URL {
        self.currentIPAURL = ipaURL
        self.currentBundleID = bundleID
        self.currentVersion = version
        self.currentTitle = title
        return getManifestInstallURL()
    }
    
    /// Starts serving the specified IPA for local HTTPS installation
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
            let tlsOptions = LocalInstallServer.createTLSOptions()
            let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
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
    
    /// Opens Safari to install the Local CA configuration profile for trusted HTTPS installation
    public func installLocalCAProfile() {
        if !isRunning {
            try? start()
        }
        let url = URL(string: "https://127.0.0.1:\(port)/ca.mobileconfig")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    /// Opens Safari to install the UDID configuration profile to automatically retrieve device UDID
    public func installUDIDProfile() {
        if !isRunning {
            try? start()
        }
        let url = URL(string: "https://127.0.0.1:\(port)/udid.mobileconfig")!
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
            } else if path.contains("udid.mobileconfig") {
                let profile = self.generateUDIDProfileXML()
                let response = "HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config; charset=utf-8\r\nContent-Disposition: attachment; filename=\"UniSignUDID.mobileconfig\"\r\nContent-Length: \(profile.utf8.count)\r\nConnection: close\r\n\r\n\(profile)"
                connection.send(content: response.data(using: .utf8), contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            } else if path.contains("receive_udid") {
                if let udid = self.extractUDIDFromPayload(requestStr) {
                    DeviceInfoHelper.setCustomUDID(udid)
                    NotificationCenter.default.post(name: NSNotification.Name("UniSignUDIDUpdatedNotification"), object: nil)
                }
                let redirectHTML = self.generateUDIDSuccessHTML()
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(redirectHTML.utf8.count)\r\nConnection: close\r\n\r\n\(redirectHTML)"
                connection.send(content: response.data(using: .utf8), contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            } else if path.contains("app.ipa") {
                guard let ipaURL = self.currentIPAURL, let ipaData = try? Data(contentsOf: ipaURL) else {
                    let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    connection.send(content: notFound.data(using: .utf8), contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                        connection.cancel()
                    }))
                    return
                }
                
                let headers = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"\(self.currentTitle).ipa\"\r\nContent-Length: \(ipaData.count)\r\nConnection: close\r\n\r\n"
                var fullResponse = headers.data(using: .utf8) ?? Data()
                fullResponse.append(ipaData)
                
                connection.send(content: fullResponse, contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            } else {
                let html = self.generateHTMLPage()
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
                connection.send(content: response.data(using: .utf8), contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
    }
    
    private func generateHTMLPage() -> String {
        let installLink = getManifestInstallURL().absoluteString
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <title>\(currentTitle) - UniSign 本地极速安装</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif; background: #0F172A; color: #FFFFFF; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
            .card { background: rgba(30, 41, 59, 0.85); backdrop-filter: blur(20px); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 24px; padding: 32px 24px; text-align: center; max-width: 400px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
            .icon { font-size: 56px; margin-bottom: 12px; }
            h1 { font-size: 20px; margin: 0 0 6px 0; font-weight: 700; }
            p { font-size: 13px; color: #94A3B8; margin: 0 0 24px 0; line-height: 1.5; }
            .badge { display: inline-block; background: #0066EB; color: white; padding: 4px 12px; border-radius: 12px; font-size: 11px; font-weight: 600; margin-bottom: 20px; }
            .btn { display: block; width: 100%; padding: 15px 0; margin-bottom: 12px; border-radius: 14px; font-size: 15px; font-weight: 600; text-decoration: none; box-sizing: border-box; transition: all 0.2s; }
            .btn-green { background: linear-gradient(135deg, #10B981, #059669); color: white; box-shadow: 0 6px 20px rgba(16, 185, 129, 0.35); }
            .btn-secondary { background: rgba(255, 255, 255, 0.1); color: #E2E8F0; border: 1px solid rgba(255, 255, 255, 0.15); }
            .guide { background: rgba(15, 23, 42, 0.6); border-radius: 14px; padding: 16px; margin-top: 20px; text-align: left; font-size: 11px; color: #94A3B8; line-height: 1.6; }
            .guide ol { padding-left: 18px; margin: 6px 0 0 0; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">📦</div>
            <h1>\(currentTitle)</h1>
            <div><span class="badge">v\(currentVersion)</span></div>
            <p>Bundle ID: <code>\(currentBundleID)</code><br>应用已签名完成，支持本地安全 HTTPS 极速直装！</p>
            
            <a href="\(installLink)" class="btn btn-green">📲 点击直接安装到本手机</a>
            <a href="/app.ipa" class="btn btn-secondary" download="\(currentTitle).ipa">📥 下载 IPA 文件</a>
            <a href="/ca.mobileconfig" class="btn btn-secondary">🛡️ 配置本地 CA 信任证书</a>
            
            <div class="guide">
              <strong style="color: #38BDF8;">💡 本地安装说明：</strong>
              <ol>
                <li>初次安装请点击上方「配置本地 CA 信任证书」，在系统「设置 -> 已下载描述文件」安装并于「关于本机 -> 证书信任设置」开启信任。</li>
                <li>安装完成后首次打开应用，请前往「设置 -> 通用 -> VPN 与设备管理」信任签名证书。</li>
                <li>iOS 16+ 需开启「设置 -> 隐私与安全性 -> 开发者模式」。</li>
              </ol>
            </div>
          </div>
        </body>
        </html>
        """
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
                            <string>https://127.0.0.1:\(port)/app.ipa</string>
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
        let certUUID = UUID().uuidString
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadDisplayName</key>
            <string>UniSign 本地极速安装证书 (Root CA)</string>
            <key>PayloadDescription</key>
            <string>信任此证书可允许 iOS 系统直接从本地安全 HTTPS 极速安装已签名 IPA，100% 解决连接失败与证书拦截问题</string>
            <key>PayloadIdentifier</key>
            <string>com.unisign.localca.\(uuid)</string>
            <key>PayloadOrganization</key>
            <string>UniSign</string>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(uuid)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadType</key>
                    <string>com.apple.security.root</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                    <key>PayloadIdentifier</key>
                    <string>com.unisign.localca.cert.\(certUUID)</string>
                    <key>PayloadUUID</key>
                    <string>\(certUUID)</string>
                    <key>PayloadDisplayName</key>
                    <string>UniSign Local Root CA</string>
                    <key>PayloadDescription</key>
                    <string>UniSign 本地安装根证书凭据</string>
                    <key>PayloadCertificateFileName</key>
                    <string>UniSignRootCA.cer</string>
                    <key>PayloadContent</key>
                    <data>\(LocalInstallServer.caCertBase64)</data>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }
    
    private func generateUDIDProfileXML() -> String {
        let uuid = UUID().uuidString
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadDisplayName</key>
            <string>UniSign 自动获取设备 UDID</string>
            <key>PayloadDescription</key>
            <string>用于一键安全获取本机物理设备 UDID，方便免费 Apple ID 或开发者证书绑定设备。</string>
            <key>PayloadIdentifier</key>
            <string>com.unisign.udid.\(uuid)</string>
            <key>PayloadOrganization</key>
            <string>UniSign</string>
            <key>PayloadType</key>
            <string>Profile Service</string>
            <key>PayloadUUID</key>
            <string>\(uuid)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadContent</key>
            <dict>
                <key>URL</key>
                <string>https://127.0.0.1:\(port)/receive_udid</string>
                <key>DeviceAttributes</key>
                <array>
                    <string>UDID</string>
                    <string>PRODUCT</string>
                    <string>VERSION</string>
                    <string>SERIAL</string>
                </array>
            </dict>
        </dict>
        </plist>
        """
    }
    
    private func extractUDIDFromPayload(_ payload: String) -> String? {
        if let startRange = payload.range(of: "<key>UDID</key>") {
            let afterKey = payload[startRange.upperBound...]
            if let stringStart = afterKey.range(of: "<string>"),
               let stringEnd = afterKey.range(of: "</string>") {
                let udid = String(afterKey[stringStart.upperBound..<stringEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !udid.isEmpty {
                    return udid
                }
            }
        }
        return nil
    }
    
    private func generateUDIDSuccessHTML() -> String {
        let currentUDID = DeviceInfoHelper.getDeviceUDID()
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <title>UDID 获取成功 - UniSign</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif; background: #0F172A; color: #FFFFFF; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
            .card { background: rgba(30, 41, 59, 0.85); backdrop-filter: blur(20px); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 24px; padding: 32px 24px; text-align: center; max-width: 400px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
            .icon { font-size: 56px; margin-bottom: 12px; }
            h1 { font-size: 20px; margin: 0 0 6px 0; font-weight: 700; color: #34D399; }
            p { font-size: 13px; color: #94A3B8; margin: 0 0 20px 0; line-height: 1.5; }
            .code-box { background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 14px; font-family: monospace; font-size: 13px; color: #38BDF8; word-break: break-all; margin-bottom: 24px; }
            .btn { display: block; width: 100%; padding: 15px 0; border-radius: 14px; font-size: 15px; font-weight: 600; text-decoration: none; box-sizing: border-box; background: #0066EB; color: white; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">✅</div>
            <h1>设备 UDID 获取成功</h1>
            <p>已自动识别并同步至 UniSign 证书与设备中心：</p>
            <div class="code-box">\(currentUDID)</div>
            <a href="unisign://open" class="btn">📱 返回 UniSign App</a>
          </div>
        </body>
        </html>
        """
    }
}
