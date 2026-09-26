import Foundation
import UIKit

public enum LogCategory: String, CaseIterable {
    case general = "INFO"
    case sign = "SIGN"
    case cert = "CERT"
    case appleID = "APPLEID"
    case install = "INSTALL"
    case zip = "ZIP"
    case warn = "WARN"
    case error = "ERROR"
}

public struct LogEntry {
    public let timestamp: Date
    public let category: LogCategory
    public let message: String
    
    public var formattedText: String {
        let formatter = AppLogger.dateFormatter
        return "[\(formatter.string(from: timestamp))] [\(category.rawValue)] \(message)"
    }
}

public class AppLogger {
    public static let shared = AppLogger()
    
    public static let logNotification = Notification.Name("UniSignAppLoggerNewLogNotification")
    
    private let queue = DispatchQueue(label: "com.unisign.logger", qos: .utility)
    private var entries: [LogEntry] = []
    private let maxEntries = 3000
    
    fileprivate static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
    
    public var logFileURL: URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logDir = docs.appendingPathComponent("Logs")
        try? fm.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
        return logDir.appendingPathComponent("unisign_debug.log")
    }
    
    private init() {
        rotateLogFileIfNeeded()
        log("UniSign AppLogger 初始化完成，持久化路径: \(logFileURL.lastPathComponent)", category: .general)
    }
    
    public func log(_ message: String, category: LogCategory = .general) {
        let entry = LogEntry(timestamp: Date(), category: category, message: message)
        
        // Console print
        print(entry.formattedText)
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
            
            // Append to disk file
            self.appendToFile(entry.formattedText + "\n")
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AppLogger.logNotification, object: entry)
            }
        }
    }
    
    private func appendToFile(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        let fileURL = logFileURL
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(data)
            }
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
    
    private func rotateLogFileIfNeeded() {
        let fileURL = logFileURL
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64, size > 10 * 1024 * 1024 { // 10MB
            let backupURL = fileURL.deletingPathExtension().appendingPathExtension("old.log")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: fileURL, to: backupURL)
        }
    }
    
    public func getLogs(category: LogCategory? = nil) -> String {
        return queue.sync {
            let filtered = category == nil ? entries : entries.filter { $0.category == category }
            return filtered.map { $0.formattedText }.joined(separator: "\n")
        }
    }
    
    public func getDiskLogText() -> String {
        return (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? getLogs()
    }
    
    public func clearLogs() {
        queue.sync {
            entries.removeAll()
            try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        }
        log("运行日志已清空", category: .general)
    }
    
    public func getLogFileSizeDescription() -> String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let size = attrs[.size] as? Int64 {
            let kb = Double(size) / 1024.0
            if kb < 1024 {
                return String(format: "%.1f KB", kb)
            } else {
                return String(format: "%.2f MB", kb / 1024.0)
            }
        }
        return "0 KB"
    }
}
