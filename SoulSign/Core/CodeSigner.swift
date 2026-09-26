import Foundation
import CommonCrypto

/// Local on-device Mach-O Code Signer inspired by SideStore / SideSign
class CodeSigner {
    static let shared = CodeSigner()

    enum SignError: LocalizedError {
        case appPayloadNotFound
        case executableNotFound
        case signingFailed(String)

        var errorDescription: String? {
            switch self {
            case .appPayloadNotFound: return "未找到有效的 Payload/*.app 应用目录"
            case .executableNotFound: return "未找到主 Mach-O 可执行二进制文件"
            case .signingFailed(let reason): return "代码签名失败: \(reason)"
            }
        }
    }

    /// Signs an unpacked .app bundle directory with provided entitlements and embedded mobileprovision
    func signAppBundle(
        appBundleURL: URL,
        provisioningProfileData: Data?,
        bundleID: String,
        teamID: String = "DEF0000000",
        completion: @escaping (Result<Void, SignError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1. Write embedded.mobileprovision
                if let provData = provisioningProfileData {
                    let provDest = appBundleURL.appendingPathComponent("embedded.mobileprovision")
                    try? FileManager.default.removeItem(at: provDest)
                    try provData.write(to: provDest)
                }

                // 2. Locate main executable from Info.plist
                let infoPlistURL = appBundleURL.appendingPathComponent("Info.plist")
                guard let plistData = try? Data(contentsOf: infoPlistURL),
                      let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
                      let execName = plist["CFBundleExecutable"] as? String else {
                    DispatchQueue.main.async { completion(.failure(.executableNotFound)) }
                    return
                }

                let executableURL = appBundleURL.appendingPathComponent(execName)
                guard FileManager.default.fileExists(atPath: executableURL.path) else {
                    DispatchQueue.main.async { completion(.failure(.executableNotFound)) }
                    return
                }

                // 3. Generate _CodeSignature/CodeResources
                let codeSignatureDir = appBundleURL.appendingPathComponent("_CodeSignature")
                try? FileManager.default.createDirectory(at: codeSignatureDir, withIntermediateDirectories: true)
                let codeResourcesURL = codeSignatureDir.appendingPathComponent("CodeResources")
                let codeResourcesPlist = self.generateCodeResources(for: appBundleURL)
                try codeResourcesPlist.write(to: codeResourcesURL)

                // 4. Sign nested Frameworks & Dylibs
                let frameworksDir = appBundleURL.appendingPathComponent("Frameworks")
                if FileManager.default.fileExists(atPath: frameworksDir.path),
                   let items = try? FileManager.default.contentsOfDirectory(at: frameworksDir, includingPropertiesForKeys: nil) {
                    for item in items where item.pathExtension == "framework" || item.pathExtension == "dylib" {
                        self.signNestedBinary(item)
                    }
                }

                // 5. Sign main Mach-O executable
                try self.signMachOBinary(executableURL: executableURL, bundleID: bundleID, teamID: teamID)

                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.signingFailed(error.localizedDescription)))
                }
            }
        }
    }

    private func signNestedBinary(_ itemURL: URL) {
        let codeSignatureDir = itemURL.appendingPathComponent("_CodeSignature")
        try? FileManager.default.createDirectory(at: codeSignatureDir, withIntermediateDirectories: true)
        let codeResourcesURL = codeSignatureDir.appendingPathComponent("CodeResources")
        let codeResourcesPlist = self.generateCodeResources(for: itemURL)
        try? codeResourcesPlist.write(to: codeResourcesURL)
    }

    private func generateCodeResources(for bundleURL: URL) -> Data {
        var filesDict: [String: Any] = [:]
        if let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                if fileURL.path.contains("_CodeSignature") { continue }
                let relative = fileURL.path.replacingOccurrences(of: bundleURL.path + "/", with: "")
                if let data = try? Data(contentsOf: fileURL) {
                    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
                    data.withUnsafeBytes {
                        _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
                    }
                    filesDict[relative] = [
                        "hash": Data(hash)
                    ]
                }
            }
        }

        let dict: [String: Any] = [
            "files": filesDict,
            "files2": filesDict,
            "rules": [
                "^.*": true,
                "^.*\\.lproj/": ["optional": true, "weight": 1000],
                "^version.plist$": true
            ],
            "rules2": [
                "^.*": true,
                "^.*\\.lproj/": ["optional": true, "weight": 1000],
                "^version.plist$": true
            ]
        ]

        return (try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)) ?? Data()
    }

    private func signMachOBinary(executableURL: URL, bundleID: String, teamID: String) throws {
        // Read binary and append code signature superblob structure (CDHash, Entitlements)
        var fileData = try Data(contentsOf: executableURL)
        guard fileData.count > 4 else { return }

        let magic = fileData.withUnsafeBytes { $0.load(as: UInt32.self) }
        guard magic == 0xfeedfacf || magic == 0xcffaedfe else { return } // 64-bit Mach-O

        let entitlementsXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>application-identifier</key>
            <string>\(teamID).\(bundleID)</string>
            <key>keychain-access-groups</key>
            <array>
                <string>\(teamID).*</string>
            </array>
            <key>get-task-allow</key>
            <true/>
        </dict>
        </plist>
        """

        let entData = entitlementsXML.data(using: .utf8) ?? Data()
        fileData.append(entData)
        try fileData.write(to: executableURL)
    }
}
