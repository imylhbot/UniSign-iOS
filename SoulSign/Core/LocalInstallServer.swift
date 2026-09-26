import Foundation
import Network
import UIKit

class LocalInstallServer {
    static let shared = LocalInstallServer()

    var port: UInt16 = 24302
    private var listener: NWListener?
    private(set) var isRunning: Bool = false

    private var currentIPAURL: URL?
    private var currentBundleID: String = "com.soulsign.signedapp"
    private var currentAppTitle: String = "SoulSign App"

    private init() {}

    func start() {
        guard !isRunning else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        do {
            listener = try NWListener(using: .tcp, on: nwPort)
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isRunning = true
                    AppLogger.shared.log("本地 OTA 安装服务已启动: http://127.0.0.1:\(self?.port ?? 24302)", category: .server)
                case .failed:
                    self?.isRunning = false
                    AppLogger.shared.log("本地 OTA 安装服务进入异常状态", category: .server)
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            AppLogger.shared.log("启动本地安装服务失败: \(error.localizedDescription)", category: .server)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    func installApp(ipaURL: URL, bundleID: String, title: String) {
        self.currentIPAURL = ipaURL
        self.currentBundleID = bundleID
        self.currentAppTitle = title

        AppLogger.shared.log("准备安装应用: \(title) (\(bundleID)), IPA 路径: \(ipaURL.lastPathComponent)", category: .server)

        start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let manifestURL = "http://127.0.0.1:\(self.port)/manifest.plist"
            let itmsURLStr = "itms-services://?action=download-manifest&url=\(manifestURL)"

            if let url = URL(string: itmsURLStr) {
                AppLogger.shared.log("正在唤起 iOS SpringBoard 安装协议: \(itmsURLStr)", category: .server)
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        AppLogger.shared.log("已成功触发系统安装弹窗，请在桌面查看安装进度", category: .server)
                    } else {
                        AppLogger.shared.log("唤起 itms-services 协议未成功", category: .server)
                    }
                }
            }
        }
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
        let isHead = reqStr.hasPrefix("HEAD")
        if path.contains("manifest.plist") {
            let manifest = generateManifestXML(bundleID: currentBundleID, title: currentAppTitle)
            let response = "HTTP/1.1 200 OK\r\nContent-Type: application/xml\r\nContent-Length: \(manifest.utf8.count)\r\nConnection: close\r\n\r\n" + (isHead ? "" : manifest)
            send(response, on: connection)
            AppLogger.shared.log("已分发 manifest.plist 给系统安装程序", category: .server)

        } else if path.contains("app.ipa") {
            AppLogger.shared.log("系统安装程序请求下载 app.ipa", category: .server)
            if let ipaURL = currentIPAURL, let ipaData = try? Data(contentsOf: ipaURL) {
                let header = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nAccept-Ranges: bytes\r\nContent-Disposition: attachment; filename=\"app.ipa\"\r\nContent-Length: \(ipaData.count)\r\nConnection: close\r\n\r\n"
                var fullResponse = header.data(using: .utf8)!
                if !isHead {
                    fullResponse.append(ipaData)
                }
                sendData(fullResponse, on: connection)
                AppLogger.shared.log("已开始传输 IPA 安装包 (\(ipaData.count) 字节)", category: .server)
            } else {
                let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                send(notFound, on: connection)
            }

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
            sendData(data, on: connection)
        } else {
            connection.cancel()
        }
    }

    private func sendData(_ data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    func installUDIDProfile() {
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
            <string>用于一键安全获取当前设备的真实硬件 UDID</string>
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
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        return nil
    }
}
