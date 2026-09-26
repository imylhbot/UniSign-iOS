import Foundation

enum LogCategory: String, CaseIterable {
    case general = "ℹ️ 系统"
    case auth = "🔐 认证"
    case portal = "🍎 开发者服务"
    case signer = "✍️ 签名引擎"
    case quota = "📊 配额管理"
    case renewal = "⚡ 证书续签"
    case server = "🌐 本地服务"
}

class AppLogger {
    static let shared = AppLogger()

    private let enabledKey = "SoulSign_EnableLogging"
    private var logs: [String] = []
    private let lock = NSLock()
    private let maxEntries = 500

    private init() {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            UserDefaults.standard.set(true, forKey: enabledKey)
        }
        loadLogsFromFile()
        log("SoulSign 日志模块已初始化", category: .general)
    }

    var isLoggingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            NotificationCenter.default.post(name: NSNotification.Name("SoulSignLoggingSettingChanged"), object: nil)
        }
    }

    private var logFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("SoulSign_Operation.log")
    }

    func log(_ message: String, category: LogCategory = .general) {
        guard isLoggingEnabled else { return }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = df.string(from: Date())
        let entry = "[\(timestamp)] [\(category.rawValue)] \(message)"

        lock.lock()
        logs.append(entry)
        if logs.count > maxEntries {
            logs.removeFirst(logs.count - maxEntries)
        }
        let fullText = logs.joined(separator: "\n")
        lock.unlock()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            try? fullText.data(using: .utf8)?.write(to: self.logFileURL)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SoulSignNewLogEntryNotification"), object: entry)
            }
        }

        #if DEBUG
        print(entry)
        #endif
    }

    func getLogs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return logs
    }

    func exportLogText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return logs.joined(separator: "\n")
    }

    func clearLogs() {
        lock.lock()
        logs.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
        lock.unlock()

        NotificationCenter.default.post(name: NSNotification.Name("SoulSignNewLogEntryNotification"), object: nil)
        log("日志已清空", category: .general)
    }

    private func loadLogsFromFile() {
        if let data = try? Data(contentsOf: logFileURL),
           let text = String(data: data, encoding: .utf8) {
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            logs = Array(lines.suffix(maxEntries))
        }
    }
}
