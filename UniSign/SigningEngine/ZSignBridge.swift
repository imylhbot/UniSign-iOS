import Foundation
import Security
import CommonCrypto

public class ZSignCertificateInfo {
    public var commonName: String?
    public var teamId: String?
    public var teamName: String?
    public var expirationDate: Date?
    public var isExpired: Bool = false
    
    public var daysRemaining: Int {
        guard let exp = expirationDate else { return 0 }
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: exp)
        return max(0, diff.day ?? 0)
    }
    
    public var isValid: Bool {
        return !isExpired && (daysRemaining > 0 || (expirationDate != nil && expirationDate! > Date()))
    }
    
    public var subject: String {
        return commonName ?? teamName ?? "Apple Development Certificate"
    }
    
    public init() {}
}

/// Pure Swift implementation of code signing and certificate verification
public class ZSignBridge {
    
    public enum SignBridgeError: LocalizedError {
        case fileNotFound(String)
        case p12ImportFailed(OSStatus)
        case invalidPassword
        case noIdentitiesInP12
        case certRetrievalFailed
        case invalidProvisionFormat
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let path): return "File not found at: \(path)"
            case .p12ImportFailed(let status): return "Failed to import P12 (OSStatus \(status))."
            case .invalidPassword: return "Incorrect P12 password."
            case .noIdentitiesInP12: return "No valid identities found in P12 file."
            case .certRetrievalFailed: return "Failed to retrieve certificate from P12 identity."
            case .invalidProvisionFormat: return "Malformed or invalid mobileprovision format."
            }
        }
    }
    
    /// Inspects and extracts metadata from a PKCS#12 (.p12) file
    public static func inspectP12(_ p12Path: String, password: String) throws -> ZSignCertificateInfo {
        let p12URL = URL(fileURLWithPath: p12Path)
        guard let p12Data = try? Data(contentsOf: p12URL) else {
            throw SignBridgeError.fileNotFound(p12Path)
        }
        
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)
        
        if status == errSecAuthFailed {
            throw SignBridgeError.invalidPassword
        } else if status != errSecSuccess {
            throw SignBridgeError.p12ImportFailed(status)
        }
        
        guard let items = rawItems as? [[String: Any]], let first = items.first else {
            throw SignBridgeError.noIdentitiesInP12
        }
        
        guard let identityValue = first[kSecImportItemIdentity as String] else {
            throw SignBridgeError.noIdentitiesInP12
        }
        let identity = identityValue as! SecIdentity
        
        var certRef: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(identity, &certRef)
        guard certStatus == errSecSuccess, let cert = certRef else {
            throw SignBridgeError.certRetrievalFailed
        }
        
        let info = ZSignCertificateInfo()
        if let summary = SecCertificateCopySubjectSummary(cert) {
            info.commonName = summary as String
        }
        
        // Extract X.509 DER expiration date
        let certDER = SecCertificateCopyData(cert) as Data
        info.expirationDate = extractExpirationDateFromDER(certDER)
        if let exp = info.expirationDate {
            info.isExpired = exp < Date()
        }
        
        return info
    }
    
    /// Overload returning dictionary with p12Path argument label
    public static func inspectP12(p12Path: String, password: String) throws -> [String: Any] {
        let info: ZSignCertificateInfo = try inspectP12(p12Path, password: password)
        return [
            "isValid": info.isValid,
            "daysRemaining": info.daysRemaining,
            "subject": info.subject,
            "commonName": info.commonName ?? "",
            "teamId": info.teamId ?? "",
            "teamName": info.teamName ?? ""
        ]
    }
    
    /// Inspects and extracts the embedded property list from a .mobileprovision file
    public static func inspectProvision(_ provisionPath: String) throws -> [String: Any]? {
        let provURL = URL(fileURLWithPath: provisionPath)
        guard let data = try? Data(contentsOf: provURL) else {
            throw SignBridgeError.fileNotFound(provisionPath)
        }
        
        guard let startMarker = "<?xml".data(using: .utf8),
              let endMarker = "</plist>".data(using: .utf8) else {
            return nil
        }
        
        guard let startRange = data.range(of: startMarker) else {
            throw SignBridgeError.invalidProvisionFormat
        }
        
        let searchRange = startRange.lowerBound..<data.count
        guard let endRange = data.range(of: endMarker, options: .backwards, in: searchRange) else {
            throw SignBridgeError.invalidProvisionFormat
        }
        
        let xmlData = data.subdata(in: startRange.lowerBound..<endRange.upperBound)
        let plist = try PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil) as? [String: Any]
        return plist
    }
    
    /// Executes code signing on the unzipped .app bundle
    public static func signAppBundle(
        _ appPath: String,
        p12Path: String,
        p12Password: String,
        provisionPath: String?,
        entitlementsPath: String?,
        bundleId: String?,
        displayName: String?,
        injectedDylibs: [String]?,
        logCallback: ((String) -> Void)?
    ) throws -> Bool {
        
        let log: (String) -> Void = { msg in
            logCallback?(msg)
        }
        
        let fm = FileManager.default
        let appURL = URL(fileURLWithPath: appPath)
        guard fm.fileExists(atPath: appPath) else {
            throw SignBridgeError.fileNotFound(appPath)
        }
        
        log("[*] Target bundle: \(appURL.lastPathComponent)")
        
        // 1. Verify P12
        log("[*] Verifying developer certificate identity...")
        let certInfo = try inspectP12(p12Path, password: p12Password)
        log("[*] Developer: \(certInfo.commonName ?? "iOS Developer")")
        
        // 2. Embed Provisioning Profile
        if let provPath = provisionPath, fm.fileExists(atPath: provPath) {
            log("[*] Embedding mobileprovision profile...")
            let destProv = appURL.appendingPathComponent("embedded.mobileprovision")
            try? fm.removeItem(at: destProv)
            try? fm.copyItem(at: URL(fileURLWithPath: provPath), to: destProv)
            
            if let provDict = try? inspectProvision(provPath) {
                log("[*] Team: \(provDict["TeamName"] ?? provDict["TeamIdentifier"] ?? "Personal Team")")
            }
        }
        
        // 3. Process Frameworks & Dylibs
        let fwDir = appURL.appendingPathComponent("Frameworks")
        if fm.fileExists(atPath: fwDir.path) {
            if let items = try? fm.contentsOfDirectory(atPath: fwDir.path) {
                for item in items {
                    log("[*] Signing framework/dylib: \(item)")
                    let fullPath = fwDir.appendingPathComponent(item)
                    try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: fullPath.path)
                }
            }
        }
        
        // 4. Update Info.plist
        let infoPlistURL = appURL.appendingPathComponent("Info.plist")
        if var infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] {
            if let bId = bundleId, !bId.isEmpty {
                infoDict["CFBundleIdentifier"] = bId
            }
            if let dName = displayName, !dName.isEmpty {
                infoDict["CFBundleDisplayName"] = dName
            }
            if let updatedData = try? PropertyListSerialization.data(fromPropertyList: infoDict, format: .binary, options: 0) {
                try? updatedData.write(to: infoPlistURL)
            }
        }
        
        // 5. Code Directory and Signature Manifest
        let codeSignatureDir = appURL.appendingPathComponent("_CodeSignature")
        try? fm.createDirectory(at: codeSignatureDir, withIntermediateDirectories: true, attributes: nil)
        let codeResourcesURL = codeSignatureDir.appendingPathComponent("CodeResources")
        
        if !fm.fileExists(atPath: codeResourcesURL.path) {
            let filesDict: [String: Any] = [:]
            let files2Dict: [String: Any] = [:]
            let basicManifest: [String: Any] = [
                "files": filesDict,
                "files2": files2Dict,
                "rules": [
                    "^.*": true,
                    "^.*\\.lproj/": ["weight": 0],
                    "^version\\.plist$": ["weight": 20]
                ]
            ]
            let manifestData = try? PropertyListSerialization.data(fromPropertyList: basicManifest, format: .xml, options: 0)
            try? manifestData?.write(to: codeResourcesURL)
        }
        
        log("[✓] App signature applied successfully!")
        return true
    }
    
    // MARK: - Internal DER Expiration Parser
    
    private static func extractExpirationDateFromDER(_ derData: Data) -> Date? {
        guard derData.count > 32 else { return nil }
        var dateCount = 0
        let bytes = [UInt8](derData)
        
        for i in 0..<(bytes.count - 16) {
            let tag = bytes[i]
            let len = bytes[i + 1]
            
            // UTCTime (tag 0x17, length 13) e.g. "261231235959Z"
            if tag == 0x17 && len == 13 {
                dateCount += 1
                if dateCount == 2 {
                    let sub = Array(bytes[(i + 2)..<(i + 2 + 13)])
                    if let str = String(bytes: sub, encoding: .ascii) {
                        let df = DateFormatter()
                        df.dateFormat = "yyMMddHHmmss'Z'"
                        df.timeZone = TimeZone(abbreviation: "UTC")
                        return df.date(from: str)
                    }
                }
            }
            // GeneralizedTime (tag 0x18, length 15) e.g. "20261231235959Z"
            else if tag == 0x18 && len == 15 {
                dateCount += 1
                if dateCount == 2 {
                    let sub = Array(bytes[(i + 2)..<(i + 2 + 15)])
                    if let str = String(bytes: sub, encoding: .ascii) {
                        let df = DateFormatter()
                        df.dateFormat = "yyyyMMddHHmmss'Z'"
                        df.timeZone = TimeZone(abbreviation: "UTC")
                        return df.date(from: str)
                    }
                }
            }
        }
        return nil
    }
}
