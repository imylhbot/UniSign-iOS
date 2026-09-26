import Foundation
import Network
import UIKit

/// Lightweight local HTTP server for itms-services installation and UDID profile serving
public class LocalInstallServer {
    public static let shared = LocalInstallServer()

    public var port: UInt16 = 24302
    private var listener: NWListener?
    public private(set) var isRunning: Bool = false

    private init() {}

    public func start() {
        guard !isRunning else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        do {
            listener = try NWListener(using: .tcp, on: nwPort)
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("[SoulSign] 本地安装服务已就绪: http://127.0.0.1:\(self?.port ?? 24302)")
                case .failed:
                    self?.isRunning = false
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            print("[SoulSign] 启动本地服务失败: \(error)")
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let data = data, let reqStr = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let lines = reqStr.components(separatedBy: "\r\n")
            guard let firstLine = lines.first else {
                connection.cancel()
                return
            }

            let parts = firstLine.components(separatedBy: " ")
            guard parts.count >= 2 else {
                connection.cancel()
                return
            }

            let path = parts[1]
            self?.routePath(path, reqStr: reqStr, connection: connection)
        }
    }

    private func routePath(_ path: String, reqStr: String, connection: NWConnection) {
        if path.contains("manifest.plist") {
            let manifest = generateManifestXML(bundleID: "com.soulsign.signedapp", title: "SoulSign Signed App")
            let response = "HTTP/1.1 200 OK\r\nContent-Type: application/xml\r\nContent-Length: \(manifest.utf8.count)\r\nConnection: close\r\n\r\n\(manifest)"
            send(response, on: connection)
        } else if path.contains("udid.mobileconfig") {
            let profile = generateUDIDProfileXML()
            let response = "HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config\r\nContent-Disposition: attachment; filename=\"SoulSignUDID.mobileconfig\"\r\nContent-Length: \(profile.utf8.count)\r\nConnection: close\r\n\r\n\(profile)"
            send(response, on: connection)
        } else if path.contains("receive_udid") {
            if let udid = extractUDID(from: reqStr) {
                DeviceUDIDHelper.setCustomUDID(udid)
                NotificationCenter.default.post(name: NSNotification.Name("SoulSignUDIDUpdatedNotification"), object: nil)
            }
            let html = "<html><body><h1>UDID 获取成功！请返回 SoulSign App</h1><script>setTimeout(function(){ window.location.href='soulsign://open'; }, 1000);</script></body></html>"
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
            send(response, on: connection)
        } else {
            let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            send(response, on: connection)
        }
    }

    private func send(_ string: String, on connection: NWConnection) {
        if let data = string.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        } else {
            connection.cancel()
        }
    }

    public func installUDIDProfile() {
        start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let url = URL(string: "http://127.0.0.1:\(self.port)/udid.mobileconfig") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    private func generateManifestXML(bundleID: String, title: String) -> String {
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
                        <string>\(bundleID)</string>
                        <key>bundle-version</key>
                        <string>1.0.0</string>
                        <key>kind</key>
                        <string>software</string>
                        <key>title</key>
                        <string>\(title)</string>
                    </dict>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }

    private func generateUDIDProfileXML() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadDisplayName</key>
            <string>SoulSign 自动获取真机 UDID</string>
            <key>PayloadDescription</key>
            <string>用于一键安全获取当前 iPhone / iPad 的真实物理硬件 UDID</string>
            <key>PayloadIdentifier</key>
            <string>com.soulsign.udid.service</string>
            <key>PayloadOrganization</key>
            <string>SoulSign</string>
            <key>PayloadType</key>
            <string>Profile Service</string>
            <key>PayloadUUID</key>
            <string>\(UUID().uuidString)</string>
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
                </array>
            </dict>
        </dict>
        </plist>
        """
    }

    private func extractUDID(from request: String) -> String? {
        if let range = request.range(of: "<key>UDID</key>\\s*<string>([^<]+)</string>", options: .regularExpression) {
            let match = String(request[range])
            return match.replacingOccurrences(of: "<key>UDID</key>", with: "")
                .replacingOccurrences(of: "<string>", with: "")
                .replacingOccurrences(of: "</string>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
