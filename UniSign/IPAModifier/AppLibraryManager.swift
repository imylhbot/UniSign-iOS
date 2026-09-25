import Foundation
import UIKit

public struct SignedAppRecord: Codable, Identifiable {
    public let id: String
    public var name: String
    public var bundleId: String
    public var version: String
    public var signedDate: Date
    public var expiryDate: Date
    public var signMethod: String // "apple_id" or "p12"
    public var appleIDEmail: String?
    public var fileName: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        bundleId: String,
        version: String,
        signedDate: Date = Date(),
        expiryDate: Date,
        signMethod: String,
        appleIDEmail: String? = nil,
        fileName: String
    ) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.version = version
        self.signedDate = signedDate
        self.expiryDate = expiryDate
        self.signMethod = signMethod
        self.appleIDEmail = appleIDEmail
        self.fileName = fileName
    }
    
    public var daysRemaining: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate)
        return diff.day ?? 0
    }
    
    public var isExpired: Bool {
        return expiryDate < Date()
    }
    
    public var fileURL: URL {
        return AppLibraryManager.shared.signedDir.appendingPathComponent(fileName)
    }
    
    public var filePath: String {
        return fileURL.path
    }
}

/// Manages imported raw IPAs, tweak dylibs, and signed applications in sandbox
public class AppLibraryManager {
    public static let shared = AppLibraryManager()
    
    private let fileManager = FileManager.default
    private let signedRecordKey = "UniSign_SignedAppRecords"
    
    public var ipaDir: URL {
        let dir = documentsDir.appendingPathComponent("IPAs")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }
    
    public var dylibDir: URL {
        let dir = documentsDir.appendingPathComponent("Dylibs")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }
    
    public var signedDir: URL {
        let dir = documentsDir.appendingPathComponent("Signed")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }
    
    private var documentsDir: URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Import Operations
    
    public func importIPA(from sourceURL: URL) throws -> URL {
        let destURL = ipaDir.appendingPathComponent(sourceURL.lastPathComponent)
        try? fileManager.removeItem(at: destURL)
        try fileManager.copyItem(at: sourceURL, to: destURL)
        return destURL
    }
    
    public func importDylib(from sourceURL: URL) throws -> URL {
        let destURL = dylibDir.appendingPathComponent(sourceURL.lastPathComponent)
        try? fileManager.removeItem(at: destURL)
        try fileManager.copyItem(at: sourceURL, to: destURL)
        return destURL
    }
    
    // MARK: - Query Operations
    
    public func getUnsignedIPAs() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: ipaDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            return []
        }
        return files.filter { $0.pathExtension.lowercased() == "ipa" || $0.pathExtension.lowercased() == "zip" }
    }
    
    public func getImportedDylibs() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: dylibDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return []
        }
        return files.filter { $0.pathExtension.lowercased() == "dylib" }
    }
    
    public func getSignedApps() -> [SignedAppRecord] {
        var result: [SignedAppRecord] = []
        if let data = UserDefaults.standard.data(forKey: signedRecordKey),
           let list = try? JSONDecoder().decode([SignedAppRecord].self, from: data) {
            result = list.filter { record in
                let path = signedDir.appendingPathComponent(record.fileName).path
                return fileManager.fileExists(atPath: path)
            }
        }
        
        // Fallback: Scan signed directory for any .ipa or .tipa files not yet tracked
        if let files = try? fileManager.contentsOfDirectory(at: signedDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) {
            for file in files where file.pathExtension.lowercased() == "ipa" || file.pathExtension.lowercased() == "tipa" {
                if !result.contains(where: { $0.fileName == file.lastPathComponent }) {
                    let plist = ZipEngine.readInfoPlist(from: file)
                    let name = (plist?["CFBundleDisplayName"] as? String) ?? (plist?["CFBundleName"] as? String) ?? file.deletingPathExtension().lastPathComponent
                    let bundleId = (plist?["CFBundleIdentifier"] as? String) ?? "com.unisign.signed"
                    let version = (plist?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
                    let autoRecord = SignedAppRecord(
                        name: name,
                        bundleId: bundleId,
                        version: version,
                        expiryDate: Date().addingTimeInterval(7 * 24 * 3600),
                        signMethod: "apple_id",
                        fileName: file.lastPathComponent
                    )
                    result.append(autoRecord)
                }
            }
        }
        return result
    }
    
    public func recordSignedApp(_ record: SignedAppRecord) {
        var list = getSignedApps()
        list.removeAll(where: { $0.bundleId == record.bundleId })
        list.insert(record, at: 0)
        saveSignedApps(list)
    }
    
    public func removeSignedApp(id: String) {
        var list = getSignedApps()
        if let rec = list.first(where: { $0.id == id }) {
            let path = signedDir.appendingPathComponent(rec.fileName)
            try? fileManager.removeItem(at: path)
        }
        list.removeAll(where: { $0.id == id })
        saveSignedApps(list)
    }
    
    public func deleteSignedApp(id: String) {
        removeSignedApp(id: id)
    }
    
    public func registerSignedApp(
        ipaURL: URL,
        name: String,
        bundleId: String,
        version: String,
        signMethod: String,
        appleIDEmail: String? = nil,
        expirationDate: Date = Date().addingTimeInterval(7 * 24 * 3600)
    ) -> SignedAppRecord {
        let destURL = signedDir.appendingPathComponent(ipaURL.lastPathComponent)
        if ipaURL.standardizedFileURL.path != destURL.standardizedFileURL.path {
            try? fileManager.removeItem(at: destURL)
            try? fileManager.copyItem(at: ipaURL, to: destURL)
        }
        let record = SignedAppRecord(
            name: name,
            bundleId: bundleId,
            version: version,
            expiryDate: expirationDate,
            signMethod: signMethod,
            appleIDEmail: appleIDEmail,
            fileName: destURL.lastPathComponent
        )
        recordSignedApp(record)
        return record
    }
    
    public func deleteUnsignedIPA(url: URL) {
        try? fileManager.removeItem(at: url)
    }
    
    public func renameUnsignedIPA(at url: URL, newName: String) throws -> URL {
        var cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanName.lowercased().hasSuffix(".ipa") && !cleanName.lowercased().hasSuffix(".zip") {
            cleanName += ".ipa"
        }
        let dest = url.deletingLastPathComponent().appendingPathComponent(cleanName)
        try fileManager.moveItem(at: url, to: dest)
        return dest
    }
    
    public func deleteDylib(url: URL) {
        try? fileManager.removeItem(at: url)
    }
    
    private func saveSignedApps(_ list: [SignedAppRecord]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: signedRecordKey)
        }
    }
}
