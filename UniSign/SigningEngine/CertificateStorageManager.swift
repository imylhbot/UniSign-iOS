import Foundation
import Security

/// Central persistent storage manager for P12 certificates, passwords, and mobileprovision profiles.
public class CertificateStorageManager {
    public static let shared = CertificateStorageManager()
    
    private let certsDir: URL
    
    public var currentAppleIDPrivateKey: SecKey?
    public var currentAppleIDCertDER: Data?
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        certsDir = docs.appendingPathComponent("Certificates", isDirectory: true)
        try? FileManager.default.createDirectory(at: certsDir, withIntermediateDirectories: true, attributes: nil)
    }
    
    public var currentP12URL: URL? {
        let file = certsDir.appendingPathComponent("active_cert.p12")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
    
    public var currentProvisionURL: URL? {
        let file = certsDir.appendingPathComponent("active.mobileprovision")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
    
    public var currentP12Name: String? {
        get {
            return UserDefaults.standard.string(forKey: "unisign_active_p12_name")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "unisign_active_p12_name")
        }
    }
    
    public var currentP12Password: String {
        get {
            return UserDefaults.standard.string(forKey: "unisign_active_p12_password") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "unisign_active_p12_password")
        }
    }
    
    public func saveP12(from sourceURL: URL, password: String) throws {
        let dest = certsDir.appendingPathComponent("active_cert.p12")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        self.currentP12Password = password
        self.currentP12Name = sourceURL.lastPathComponent
        AppLogger.shared.log("已成功导入并保存 P12 证书: \(sourceURL.lastPathComponent)", category: .cert)
    }
    
    public func saveProvision(from sourceURL: URL) throws {
        let dest = certsDir.appendingPathComponent("active.mobileprovision")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        AppLogger.shared.log("已成功导入并保存描述文件: \(sourceURL.lastPathComponent)", category: .cert)
    }
    
    public func saveAppleIDMaterials(p12Data: Data, provisionData: Data, email: String) throws -> (p12URL: URL, provisionURL: URL) {
        let safeName = String(abs(email.lowercased().hashValue))
        let p12Dest = certsDir.appendingPathComponent("apple_id_\(safeName).p12")
        let provDest = certsDir.appendingPathComponent("apple_id_\(safeName).mobileprovision")
        
        try? FileManager.default.removeItem(at: p12Dest)
        try? FileManager.default.removeItem(at: provDest)
        
        try p12Data.write(to: p12Dest)
        try provisionData.write(to: provDest)
        
        return (p12URL: p12Dest, provisionURL: provDest)
    }
    
    public func getAppleIDMaterials(email: String) -> (p12URL: URL, provisionURL: URL)? {
        let safeName = String(abs(email.lowercased().hashValue))
        let p12Dest = certsDir.appendingPathComponent("apple_id_\(safeName).p12")
        let provDest = certsDir.appendingPathComponent("apple_id_\(safeName).mobileprovision")
        
        if FileManager.default.fileExists(atPath: p12Dest.path) && FileManager.default.fileExists(atPath: provDest.path) {
            return (p12URL: p12Dest, provisionURL: provDest)
        }
        return nil
    }
    
    public func hasValidP12Certificate() -> Bool {
        guard let p12 = currentP12URL else { return false }
        do {
            let info = try ZSignBridge.inspectP12(p12Path: p12.path, password: currentP12Password)
            return (info["isValid"] as? Bool) ?? false
        } catch {
            return false
        }
    }
    
    public func saveAppleIDPrivateKey(_ key: SecKey, email: String) {
        self.currentAppleIDPrivateKey = key
        let tag = "com.unisign.appleid.key.\(email.lowercased())".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag
        ]
        SecItemDelete(query as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecValueRef as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        AppLogger.shared.log("Keychain 保存 Apple ID 私钥状态: \(status)", category: .cert)
    }
    
    public func getAppleIDPrivateKey(email: String) -> SecKey? {
        if let memKey = currentAppleIDPrivateKey {
            return memKey
        }
        let tag = "com.unisign.appleid.key.\(email.lowercased())".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let keyRef = item {
            let key = (keyRef as! SecKey)
            self.currentAppleIDPrivateKey = key
            return key
        }
        return nil
    }
}
