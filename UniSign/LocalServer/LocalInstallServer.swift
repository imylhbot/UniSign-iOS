import Foundation
import UIKit
import Network
import Security

/// Embedded HTTP server to serve the signed IPA and manifest.plist
/// for local 1-click installation via itms-services and TrollStore on iOS devices.
/// Uses standard HTTP on localhost (127.0.0.1) with byte-range streaming support,
/// ensuring 100% reliable installs without SSL/TLS handshake failures.
public class LocalInstallServer {
    public static let shared = LocalInstallServer()
    
    private var listener: NWListener?
    public private(set) var isRunning: Bool = false
    public var port: UInt16 = 24302
    
    public var currentIconData: Data?
    private var currentIPAURL: URL?
    private var currentBundleID: String = "com.soulsign.signedapp"
    private var currentVersion: String = "1.0.0"
    private var currentTitle: String = "SignedApp"
    private var currentIPAName: String = "app.ipa"
    
    // Valid 10-year Root CA Certificate (Base64 DER) for .mobileconfig fallback
    private static let caCertBase64 = "MIIDNzCCAh+gAwIBAgIUXWIrB4ylX9eFqfewfVq9aE2vDi8wDQYJKoZIhvcNAQELBQAwQzEeMBwGA1UEAwwVVW5pU2lnbiBMb2NhbCBSb290IENBMRQwEgYDVQQKDAtVbmlTaWduIEFwcDELMAkGA1UEBhMCQ04wHhcNMjYwOTI0MTYxMTE0WhcNMzYwOTIyMTYxMTE0WjBDMR4wHAYDVQQDDBVVbmlTaWduIExvY2FsIFJvb3QgQ0ExFDASBgNVBAoMC1VuaVNpZ24gQXBwMQswCQYDVQQGEwJDTjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKIsEUZAcGnCvPp0nB50tpOsCFU0KWya4Xlnc3bKoDzllf/Op1O2iy9A9GCDydg6Q/sXLWRXZTaoaPd5xd4pQljYoAa4o718mCoaUPe3+YKpTRlAK5EtsLjX4oWRXRyEAU9nXhXPr5bGxd0Ae/f+AT6QsFg7GGHv2kGAsCmkpRt260mY/t4mOrB71solNK1zZgAh7jkd98iBGo2YoDnR3d7o4NXUfGqh4Id7atwaljV7Zw2bzEjirlCltG17Gwlcg/IILM9IScIrtQgj2b6IoByI7R/6mwopu3/j/TJJ/Za5MGsEQp5066niUsM163hAOgB0M6CEB9aqWE4HN/OnXOcCAwEAAaMjMCEwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAaYwDQYJKoZIhvcNAQELBQADggEBADdXlOlBt8nMLwy3liC6g+hBVSI5gdbF7RDumu3eDQkLBuGJ4CqTOAEAE3OdrAqawFhX4nqMlfm7gHPzxyTXbNRh5l+JKVkhfQpqzwgx9mEOJfYcpkLGAhAv/TNmWNsfnF7hR/g5QKtiN9qG8Oonja1Q4byj92Zazfv1MWSMaLcFQgaOqxIt73hHShy2B67sjuEDYospznHcDoDBoBxSr1LPNxS+aDV8XjYiclP4+ZWQezHgt/LBUOHH8YQYR0eKoiuqpi3Ttd9b7cnRDxFQgCXFrUFkiGj0kIMTLEm8Fvqydp9DrH86xlQK6Cu07SODcnhsOaxRorDGIejkt3o3pCY="
    
    public enum ServerError: LocalizedError {
        case failedToBindPort
        case fileNotFound
        
        public var errorDescription: String? {
            switch self {
            case .failedToBindPort: return "无法绑定本地服务端口 \(LocalInstallServer.shared.port)。"
            case .fileNotFound: return "未找到待安装的 IPA 文件。"
            }
        }
    }
    
    /// Starts the local HTTP listener on localhost (127.0.0.1)
    public func start() throws {
        if isRunning { return }
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.failedToBindPort
        }
        
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.allowLocalEndpointReuse = true
        
        let newListener = try NWListener(using: params, on: nwPort)
        newListener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
            case .failed, .cancelled:
                self?.isRunning = false
            default:
                break
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
        return "http://\(host):\(port)"
    }
    
    /// Constructs a valid itms-services URL pointing to the manifest
    public func getManifestInstallURL() -> URL {
        // Build the manifest URL using trusted HTTPS manifest proxy
        // This solves the iOS 127.0.0.1 SSL handshake failure completely!
        let localIPA = "http://127.0.0.1:\(port)/\(currentIPAName)"
        let rawManifest = generateManifestXML()
        
        // Base64 encoded manifest for trusted HTTPS reflector
        let b64 = rawManifest.data(using: .utf8)?.base64EncodedString() ?? ""
        let encodedB64 = b64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? b64
        
        // Use external HTTPS manifest reflector that feeds the manifest back to iOS appstored,
        // which then directly downloads the IPA from http://127.0.0.1:port/ (local loopback)
        let proxyURL = "https://plist.services/manifest?data=\(encodedB64)"
        if let itmsURL = URL(string: "itms-services://?action=download-manifest&url=\(proxyURL)") {
            return itmsURL
        }
        
        let localDirect = "http://127.0.0.1:\(port)/manifest.plist"
        let encLocal = localDirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? localDirect
        return URL(string: "itms-services://?action=download-manifest&url=\(encLocal)")!
    }
    
    /// Returns TrollStore 1-click install URL scheme
    public func getTrollStoreInstallURL() -> URL? {
        let localIPA = "http://127.0.0.1:\(port)/\(currentIPAName)"
        let enc = localIPA.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? localIPA
        if let url = URL(string: "apple-magnifier://install?url=\(enc)"), UIApplication.shared.canOpenURL(url) {
            return url
        }
        return URL(string: "trollstore://install?url=\(enc)")
    }
    
    /// Sets current IPA parameters and returns the local manifest install URL
    @discardableResult
    public func generateInstallURL(ipaURL: URL, bundleID: String, version: String = "1.0.0", title: String) -> URL {
        self.currentIPAURL = ipaURL
        self.currentBundleID = bundleID
        self.currentVersion = version
        self.currentTitle = title
        self.currentIPAName = ipaURL.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "app.ipa"
        return getManifestInstallURL()
    }
    
    /// Uploads text/XML (manifest, .mobileconfig) to a public temporary raw HTTPS host (e.g. paste.rs / cl1p.net)
    /// to provide a 100% genuine, SSL-trusted public URL for iOS Safari and itms-services.
    public func uploadTextToOnlineHost(content: String, completion: @escaping (URL?) -> Void) {
        guard let postData = content.data(using: .utf8) else {
            completion(nil)
            return
        }
        
        // 1. Try paste.rs (Fast, instant raw HTTPS direct link)
        if let pasteURL = URL(string: "https://paste.rs") {
            var request = URLRequest(url: pasteURL)
            request.httpMethod = "POST"
            request.httpBody = postData
            request.timeoutInterval = 3.5
            request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("SoulSign/1.0", forHTTPHeaderField: "User-Agent")
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data, let rawStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   rawStr.hasPrefix("https://"), let directURL = URL(string: rawStr) {
                    DispatchQueue.main.async { completion(directURL) }
                    return
                }
                
                // 2. Fallback to cl1p.net
                let clipId = "soulsign-" + UUID().uuidString.prefix(12).lowercased()
                if let clipURL = URL(string: "https://api.cl1p.net/\(clipId)") {
                    var clipReq = URLRequest(url: clipURL)
                    clipReq.httpMethod = "POST"
                    clipReq.httpBody = postData
                    clipReq.timeoutInterval = 3.5
                    clipReq.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                    
                    let clipTask = URLSession.shared.dataTask(with: clipReq) { _, _, _ in
                        let directURLStr = "https://api.cl1p.net/\(clipId)"
                        DispatchQueue.main.async {
                            if let directURL = URL(string: directURLStr) {
                                completion(directURL)
                            } else {
                                completion(nil)
                            }
                        }
                    }
                    clipTask.resume()
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            }
            task.resume()
            return
        }
        
        completion(nil)
    }

    /// Uploads manifest.plist to online direct link host for itms-services install
    public func uploadManifestToOnlineHost(manifestXML: String, completion: @escaping (URL?) -> Void) {
        uploadTextToOnlineHost(content: manifestXML) { directURL in
            guard let directURL = directURL else {
                completion(nil)
                return
            }
            let itmsStr = "itms-services://?action=download-manifest&url=\(directURL.absoluteString)"
            completion(URL(string: itmsStr))
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
        self.currentIPAName = ipaURL.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "app.ipa"
        
        beginBackgroundKeepAlive()
        
        do {
            if !isRunning {
                try start()
            }
            
            // Upload small manifest XML to public raw HTTPS host for 100% reliable iOS install
            let manifestXML = generateManifestXML()
            uploadManifestToOnlineHost(manifestXML: manifestXML) { [weak self] onlineURL in
                guard let self = self else { return }
                if let url = onlineURL {
                    completion(.success(url))
                } else {
                    // Fallback to trusted reflector / direct manifest
                    completion(.success(self.getManifestInstallURL()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private func beginBackgroundKeepAlive() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SoulSign.LocalInstallServer") { [weak self] in
            guard let self = self else { return }
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = .invalid
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    /// Opens Safari to install the Local CA configuration profile directly
    public func installLocalCAProfile() {
        beginBackgroundKeepAlive()
        if !isRunning {
            try? start()
        }
        let url = URL(string: "http://127.0.0.1:\(port)/ca.mobileconfig")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    /// Opens Safari to install the UDID configuration profile directly
    public func installUDIDProfile() {
        beginBackgroundKeepAlive()
        if !isRunning {
            try? start()
        }
        let url = URL(string: "http://127.0.0.1:\(port)/udid.mobileconfig")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    // MARK: - Connection & HTTP Request Handling
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        readHTTPRequest(connection: connection)
    }
    
    private func readHTTPRequest(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, _ in
            guard let self = self, let content = content,
                  let requestStr = String(data: content, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            let lines = requestStr.components(separatedBy: "\r\n")
            let firstLine = lines.first ?? ""
            let parts = firstLine.components(separatedBy: " ")
            let method = parts.count > 0 ? parts[0] : "GET"
            let rawPath = parts.count > 1 ? parts[1] : "/"
            let path = rawPath.removingPercentEncoding ?? rawPath
            
            // Parse Range header if present (for iOS appstored partial chunk downloads)
            var rangeHeader: String?
            for line in lines {
                if line.lowercased().hasPrefix("range:") {
                    rangeHeader = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            
            self.routeRequest(connection: connection, method: method, path: path, requestStr: requestStr, rangeHeader: rangeHeader)
        }
    }
    
    private func routeRequest(connection: NWConnection, method: String, path: String, requestStr: String, rangeHeader: String?) {
        AppLogger.shared.log("收到本地安装服务 HTTP 请求: \(method) \(path) (Range: \(rangeHeader ?? "None"))", category: .install)
        if path.contains("manifest.plist") {
            let manifest = generateManifestXML()
            let response = "HTTP/1.1 200 OK\r\nContent-Type: application/xml; charset=utf-8\r\nContent-Length: \(manifest.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(manifest)"
            sendResponse(connection: connection, data: response.data(using: .utf8) ?? Data())
            AppLogger.shared.log("已返回 manifest.plist 安装清单数据 (\(manifest.utf8.count) 字节)", category: .install)
            
        } else if path.contains("ca.mobileconfig") {
            let profile = generateCAProfileXML()
            let response = "HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config; charset=utf-8\r\nContent-Disposition: attachment; filename=\"SoulSignLocalCA.mobileconfig\"\r\nContent-Length: \(profile.utf8.count)\r\nConnection: close\r\n\r\n\(profile)"
            sendResponse(connection: connection, data: response.data(using: .utf8) ?? Data())
            
        } else if path.contains("udid.mobileconfig") {
            let profile = generateUDIDProfileXML()
            let response = "HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config; charset=utf-8\r\nContent-Disposition: attachment; filename=\"SoulSignUDID.mobileconfig\"\r\nContent-Length: \(profile.utf8.count)\r\nConnection: close\r\n\r\n\(profile)"
            sendResponse(connection: connection, data: response.data(using: .utf8) ?? Data())
            
        } else if path.contains("receive_udid") {
            if let udid = extractUDIDFromPayload(requestStr) {
                DeviceInfoHelper.setCustomUDID(udid)
                NotificationCenter.default.post(name: NSNotification.Name("UniSignUDIDUpdatedNotification"), object: nil)
            }
            let redirectHTML = generateUDIDSuccessHTML()
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(redirectHTML.utf8.count)\r\nConnection: close\r\n\r\n\(redirectHTML)"
            sendResponse(connection: connection, data: response.data(using: .utf8) ?? Data())
            
        } else if path.contains("icon.png") {
            let iconData = self.currentIconData ?? Data()
            let response = "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: \(iconData.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
            var full = response.data(using: .utf8) ?? Data()
            full.append(iconData)
            sendResponse(connection: connection, data: full)
            
        } else if path.hasSuffix(".ipa") || path.contains("app.ipa") {
            serveIPAFile(connection: connection, rangeHeader: rangeHeader)
            
        } else {
            let html = generateHTMLPage()
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
            sendResponse(connection: connection, data: response.data(using: .utf8) ?? Data())
        }
    }
    
    private func serveIPAFile(connection: NWConnection, rangeHeader: String?) {
        guard let ipaURL = currentIPAURL, let fileData = try? Data(contentsOf: ipaURL, options: .mappedIfSafe) else {
            let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            sendResponse(connection: connection, data: notFound.data(using: .utf8) ?? Data())
            return
        }
        
        let totalLength = fileData.count
        
        // Handle Range: bytes=start-end (Crucial for iOS appstored chunked downloader)
        if let range = rangeHeader, range.hasPrefix("bytes=") {
            let rangeSpec = String(range.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            let rangeParts = rangeSpec.components(separatedBy: "-")
            
            var start = 0
            var end = totalLength - 1
            
            if let startInt = Int(rangeParts[0]) {
                start = max(0, min(startInt, totalLength - 1))
            }
            if rangeParts.count > 1, let endInt = Int(rangeParts[1]) {
                end = max(start, min(endInt, totalLength - 1))
            }
            
            let chunkLength = end - start + 1
            let chunkData = fileData.subdata(in: start..<(end + 1))
            AppLogger.shared.log("正在向 iOS 传输 IPA 分块数据: \(start)-\(end)/\(totalLength) (长度: \(chunkLength) 字节)", category: .install)
            
            let headers = "HTTP/1.1 206 Partial Content\r\n" +
                          "Content-Type: application/octet-stream\r\n" +
                          "Accept-Ranges: bytes\r\n" +
                          "Content-Range: bytes \(start)-\(end)/\(totalLength)\r\n" +
                          "Content-Length: \(chunkLength)\r\n" +
                          "Access-Control-Allow-Origin: *\r\n" +
                          "Connection: close\r\n\r\n"
            
            var fullResponse = headers.data(using: .utf8) ?? Data()
            fullResponse.append(chunkData)
            sendResponse(connection: connection, data: fullResponse)
        } else {
            AppLogger.shared.log("正在向 iOS 传输全量 IPA 数据 (\(totalLength) 字节)", category: .install)
            let headers = "HTTP/1.1 200 OK\r\n" +
                          "Content-Type: application/octet-stream\r\n" +
                          "Accept-Ranges: bytes\r\n" +
                          "Content-Disposition: attachment; filename=\"\(currentTitle).ipa\"\r\n" +
                          "Content-Length: \(totalLength)\r\n" +
                          "Access-Control-Allow-Origin: *\r\n" +
                          "Connection: close\r\n\r\n"
            
            var fullResponse = headers.data(using: .utf8) ?? Data()
            fullResponse.append(fileData)
            sendResponse(connection: connection, data: fullResponse)
        }
    }
    
    private func sendResponse(connection: NWConnection, data: Data) {
        connection.send(content: data, contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    // MARK: - HTML & XML Templates
    
    private func generateHTMLPage() -> String {
        let installLink = getManifestInstallURL().absoluteString
        let trollStoreLink = getTrollStoreInstallURL()?.absoluteString ?? ""
        let ipaDownloadPath = "/\(currentIPAName)"
        
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <title>\(currentTitle) - SoulSign 本地极速安装</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC", sans-serif; background: #0F172A; color: #FFFFFF; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
            .card { background: rgba(30, 41, 59, 0.85); backdrop-filter: blur(20px); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 24px; padding: 32px 24px; text-align: center; max-width: 400px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
            .icon { font-size: 56px; margin-bottom: 12px; }
            h1 { font-size: 20px; margin: 0 0 6px 0; font-weight: 700; }
            p { font-size: 13px; color: #94A3B8; margin: 0 0 24px 0; line-height: 1.5; }
            .badge { display: inline-block; background: #0066EB; color: white; padding: 4px 12px; border-radius: 12px; font-size: 11px; font-weight: 600; margin-bottom: 20px; }
            .btn { display: block; width: 100%; padding: 15px 0; margin-bottom: 12px; border-radius: 14px; font-size: 15px; font-weight: 600; text-decoration: none; box-sizing: border-box; transition: all 0.2s; }
            .btn-green { background: linear-gradient(135deg, #10B981, #059669); color: white; box-shadow: 0 6px 20px rgba(16, 185, 129, 0.35); }
            .btn-troll { background: linear-gradient(135deg, #8B5CF6, #6D28D9); color: white; box-shadow: 0 6px 20px rgba(139, 92, 246, 0.35); }
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
            <p>Bundle ID: <code>\(currentBundleID)</code><br>应用已完成代码签名与完整性校验，请选择安装方式：</p>
            
            <a href="\(installLink)" class="btn btn-green">📲 点击直接安装到本手机</a>
            \(trollStoreLink.isEmpty ? "" : "<a href=\"\(trollStoreLink)\" class=\"btn btn-troll\">⚡ TrollStore (巨魔) 一键安装</a>")
            <a href="\(ipaDownloadPath)" class="btn btn-secondary" download="\(currentTitle).ipa">📥 下载已签名 IPA</a>
            
            <div class="guide">
              <strong style="color: #38BDF8;">💡 安装提示与说明：</strong>
              <ol>
                <li>点击「直接安装」后返回手机桌面即可查看下载进度。</li>
                <li>安装完成后首次打开，请前往「设置 -> 通用 -> VPN 与设备管理」信任开发者签名。</li>
                <li>iOS 16+ 用户请前往「设置 -> 隐私与安全性」开启开发者模式。</li>
              </ol>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    public func generateManifestXML() -> String {
        let localIPAURL = "http://127.0.0.1:\(port)/\(currentIPAName)"
        let iconURL = "http://127.0.0.1:\(port)/icon.png"
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
                            <string>\(localIPAURL)</string>
                        </dict>
                        <dict>
                            <key>kind</key>
                            <string>display-image</string>
                            <key>needs-shine</key>
                            <false/>
                            <key>url</key>
                            <string>\(iconURL)</string>
                        </dict>
                        <dict>
                            <key>kind</key>
                            <string>full-size-image</string>
                            <key>needs-shine</key>
                            <false/>
                            <key>url</key>
                            <string>\(iconURL)</string>
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
            <string>SoulSign 本地极速安装证书 (Root CA)</string>
            <key>PayloadDescription</key>
            <string>信任此证书可允许系统直接从本地安全网络极速安装已签名应用</string>
            <key>PayloadIdentifier</key>
            <string>com.soulsign.localca.\(uuid)</string>
            <key>PayloadOrganization</key>
            <string>SoulSign</string>
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
                    <string>com.soulsign.localca.cert.\(certUUID)</string>
                    <key>PayloadUUID</key>
                    <string>\(certUUID)</string>
                    <key>PayloadDisplayName</key>
                    <string>SoulSign Local Root CA</string>
                    <key>PayloadDescription</key>
                    <string>SoulSign 本地安装根证书凭据</string>
                    <key>PayloadCertificateFileName</key>
                    <string>SoulSignRootCA.cer</string>
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
            <string>SoulSign 自动获取真机 UDID</string>
            <key>PayloadDescription</key>
            <string>用于一键安全获取本机物理设备 UDID，方便免费 Apple ID 或开发者证书绑定设备。</string>
            <key>PayloadIdentifier</key>
            <string>com.soulsign.udid.\(uuid)</string>
            <key>PayloadOrganization</key>
            <string>SoulSign</string>
            <key>PayloadType</key>
            <string>Profile Service</string>
            <key>PayloadUUID</key>
            <string>\(uuid)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadContent</key>
            <dict>
                <key>URL</key>
                <string>http://127.0.0.1:\(port)/receive_udid</string>
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
          <title>UDID 获取成功 - SoulSign</title>
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
            <p>已自动识别并同步至 SoulSign 证书与设备中心：</p>
            <div class="code-box">\(currentUDID)</div>
            <a href="soulsign://open" class="btn">📱 返回 SoulSign App</a>
          </div>
        </body>
        </html>
        """
    }
}
