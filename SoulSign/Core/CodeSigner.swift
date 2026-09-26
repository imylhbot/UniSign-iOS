import Foundation
import CommonCrypto

enum SigningError: LocalizedError {
    case appBundleNotFound
    case infoPlistNotFound
    case codeSigningFailed(String)

    var errorDescription: String? {
        switch self {
        case .appBundleNotFound:
            return "未在解包目录中找到 .app 目录"
        case .infoPlistNotFound:
            return "未找到 Info.plist 文件"
        case .codeSigningFailed(let msg):
            return "签名执行失败: \(msg)"
        }
    }
}

class CodeSigner {
    static let shared = CodeSigner()

    private init() {}

    func signApp(
        appBundleURL: URL,
        provisioningProfile: Data,
        newBundleID: String? = nil,
        newDisplayName: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let infoPlistURL = appBundleURL.appendingPathComponent("Info.plist")
                guard FileManager.default.fileExists(atPath: infoPlistURL.path),
                      let plistData = try? Data(contentsOf: infoPlistURL),
                      var plist = try? PropertyListSerialization.propertyList(from: plistData, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
                    throw SigningError.infoPlistNotFound
                }

                if let newBundleID = newBundleID, !newBundleID.isEmpty {
                    plist["CFBundleIdentifier"] = newBundleID
                }

                if let newDisplayName = newDisplayName, !newDisplayName.isEmpty {
                    plist["CFBundleDisplayName"] = newDisplayName
                    plist["CFBundleName"] = newDisplayName
                }

                let updatedData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try updatedData.write(to: infoPlistURL)

                let profileURL = appBundleURL.appendingPathComponent("embedded.mobileprovision")
                try? FileManager.default.removeItem(at: profileURL)
                try provisioningProfile.write(to: profileURL)

                let codeSigURL = appBundleURL.appendingPathComponent("_CodeSignature")
                try? FileManager.default.removeItem(at: codeSigURL)
                try FileManager.default.createDirectory(at: codeSigURL, withIntermediateDirectories: true)

                let resourcesManifest = try self.generateCodeResources(for: appBundleURL)
                let resourcesData = try PropertyListSerialization.data(fromPropertyList: resourcesManifest, format: .xml, options: 0)
                try resourcesData.write(to: codeSigURL.appendingPathComponent("CodeResources"))

                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func signAppBundle(
        appBundleURL: URL,
        provisioningProfileData: Data,
        bundleID: String? = nil,
        teamID: String? = nil,
        displayName: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        signApp(
            appBundleURL: appBundleURL,
            provisioningProfile: provisioningProfileData,
            newBundleID: bundleID,
            newDisplayName: displayName,
            completion: completion
        )
    }

    private func generateCodeResources(for bundleURL: URL) throws -> [String: Any] {
        var filesDict: [String: Any] = [:]
        let fileManager = FileManager.default

        if let enumerator = fileManager.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.path.contains("/_CodeSignature") || fileURL.lastPathComponent == "embedded.mobileprovision" {
                    continue
                }

                let relativePath = fileURL.path.replacingOccurrences(of: bundleURL.path + "/", with: "")
                if let fileData = try? Data(contentsOf: fileURL) {
                    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
                    fileData.withUnsafeBytes {
                        _ = CC_SHA256($0.baseAddress, CC_LONG(fileData.count), &hash)
                    }
                    let hashData = Data(hash)
                    filesDict[relativePath] = ["hash": hashData]
                }
            }
        }

        return [
            "files": filesDict,
            "files2": filesDict,
            "rules": [
                "^.*": true,
                "^.*\\.lproj/": ["weight": 100],
                "^version\\.plist$": ["weight": 100]
            ],
            "rules2": [
                "^.*": true,
                "^.*\\.lproj/": ["weight": 100]
            ]
        ]
    }
}
