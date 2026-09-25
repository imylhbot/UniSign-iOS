import Foundation
import UIKit

/// High-level orchestrator that handles real IPA decompression, modification, dylib injection, signing, and repackaging
public class IPAManager {
    
    public struct SignConfig {
        public var ipaURL: URL
        public var p12URL: URL
        public var p12Password: String
        public var provisionURL: URL?
        public var options: PlistModifier.CustomizationOptions
        public var replacementIcon: UIImage?
        public var dylibsToInject: [URL]
        public var dylibsToRemove: [String]
        
        public init(
            ipaURL: URL,
            p12URL: URL,
            p12Password: String,
            provisionURL: URL? = nil,
            options: PlistModifier.CustomizationOptions = PlistModifier.CustomizationOptions(),
            replacementIcon: UIImage? = nil,
            dylibsToInject: [URL] = [],
            dylibsToRemove: [String] = []
        ) {
            self.ipaURL = ipaURL
            self.p12URL = p12URL
            self.p12Password = p12Password
            self.provisionURL = provisionURL
            self.options = options
            self.replacementIcon = replacementIcon
            self.dylibsToInject = dylibsToInject
            self.dylibsToRemove = dylibsToRemove
        }
    }
    
    public enum IPAError: LocalizedError {
        case fileNotFound(String)
        case unarchiveFailed(String)
        case appPayloadNotFound
        case executableNotFound
        case signingFailed(String)
        case archiveFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let path): return "文件未找到: \(path)"
            case .unarchiveFailed(let r): return "解压 IPA 失败: \(r)"
            case .appPayloadNotFound: return "未在 Payload 目录下找到 .app 应用程序包"
            case .executableNotFound: return "未找到主二进制 Mach-O 可执行文件"
            case .signingFailed(let reason): return "代码签名失败: \(reason)"
            case .archiveFailed(let r): return "重新打包压缩为 IPA 失败: \(r)"
            }
        }
    }
    
    public static let shared = IPAManager()
    public var progressHandler: ((String, Double) -> Void)?
    
    public init() {}
    
    public func modifyAndSignIPA(
        sourceIPA: URL,
        p12URL: URL,
        p12Password: String,
        mobileprovisionURL: URL?,
        newBundleId: String?,
        newDisplayName: String?,
        newVersion: String?,
        newMinOSVersion: String?,
        enableFileSharing: Bool,
        enableOpeningDocumentsInPlace: Bool,
        newIconImage: UIImage?,
        dylibsToInject: [URL],
        dylibsToRemove: [String],
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        var opts = PlistModifier.CustomizationOptions()
        opts.newBundleID = newBundleId
        opts.newDisplayName = newDisplayName
        opts.newVersion = newVersion
        opts.newMinimumOSVersion = newMinOSVersion
        opts.enableFileSharing = enableFileSharing
        opts.enableOpeningDocumentsInPlace = enableOpeningDocumentsInPlace
        
        let config = SignConfig(
            ipaURL: sourceIPA,
            p12URL: p12URL,
            p12Password: p12Password,
            provisionURL: mobileprovisionURL,
            options: opts,
            replacementIcon: newIconImage,
            dylibsToInject: dylibsToInject,
            dylibsToRemove: dylibsToRemove
        )
        
        Self.processAndSign(config: config, progress: { [weak self] pct, step in
            self?.progressHandler?(step, pct)
        }, completion: completion)
    }
    
    /// Executes the full real IPA workflow: unzip -> customize -> inject -> sign -> zip
    public static func processAndSign(
        config: SignConfig,
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let workingDir = fileManager.temporaryDirectory.appendingPathComponent("UniSign_\(UUID().uuidString)")
            
            do {
                try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true, attributes: nil)
                defer {
                    try? fileManager.removeItem(at: workingDir)
                }
                
                // 1. Real Unzip IPA using ZipEngine
                progress(0.10, "正在解压 IPA 安装包...")
                let unzippedURL = workingDir.appendingPathComponent("Unpacked")
                try fileManager.createDirectory(at: unzippedURL, withIntermediateDirectories: true, attributes: nil)
                
                do {
                    try ZipEngine.unzip(source: config.ipaURL, destination: unzippedURL) { pct, msg in
                        progress(0.10 + pct * 0.20, msg)
                    }
                } catch {
                    throw IPAError.unarchiveFailed(error.localizedDescription)
                }
                
                // 2. Locate Payload/xxx.app
                let payloadURL = unzippedURL.appendingPathComponent("Payload")
                guard fileManager.fileExists(atPath: payloadURL.path),
                      let appName = try fileManager.contentsOfDirectory(atPath: payloadURL.path).first(where: { $0.hasSuffix(".app") }) else {
                    throw IPAError.appPayloadNotFound
                }
                let appURL = payloadURL.appendingPathComponent(appName)
                progress(0.35, "定位到应用: \(appName)")
                
                // 3. Plist Modifications
                progress(0.40, "正在修改 Info.plist 配置...")
                try PlistModifier.apply(options: config.options, toAppURL: appURL)
                
                // 4. Icon Replacement
                if let newIcon = config.replacementIcon {
                    progress(0.50, "正在替换应用桌面图标...")
                    try? IconReplacer.replaceIcon(inAppURL: appURL, withImage: newIcon)
                }
                
                // 5. Mach-O & Dylib Injection / Removal
                let plist = try PlistModifier.readPlist(at: appURL)
                let exeName = (plist["CFBundleExecutable"] as? String) ?? appName.replacingOccurrences(of: ".app", with: "")
                let exeURL = appURL.appendingPathComponent(exeName)
                
                if fileManager.fileExists(atPath: exeURL.path) {
                    // Dylib Removals
                    for dylibToRemove in config.dylibsToRemove {
                        progress(0.55, "正在移除插件: \(dylibToRemove)...")
                        try? MachOModifier.removeDylib(binaryURL: exeURL, dylibNameOrPath: dylibToRemove)
                        
                        let fwFile = appURL.appendingPathComponent("Frameworks").appendingPathComponent(dylibToRemove)
                        try? fileManager.removeItem(at: fwFile)
                    }
                    
                    // Dylib Injections
                    if !config.dylibsToInject.isEmpty {
                        let frameworksDir = appURL.appendingPathComponent("Frameworks")
                        try? fileManager.createDirectory(at: frameworksDir, withIntermediateDirectories: true, attributes: nil)
                        
                        for dylibURL in config.dylibsToInject {
                            progress(0.65, "正在注入插件: \(dylibURL.lastPathComponent)...")
                            let destDylib = frameworksDir.appendingPathComponent(dylibURL.lastPathComponent)
                            try? fileManager.removeItem(at: destDylib)
                            try fileManager.copyItem(at: dylibURL, to: destDylib)
                            
                            let injectedPath = "@executable_path/Frameworks/\(dylibURL.lastPathComponent)"
                            try MachOModifier.injectDylib(binaryURL: exeURL, dylibPath: injectedPath)
                        }
                    }
                }
                
                // 6. Execute Code Signing via ZSignBridge
                progress(0.75, "正在计算代码哈希并进行签名...")
                do {
                    _ = try ZSignBridge.signAppBundle(
                        appURL.path,
                        p12Path: config.p12URL.path,
                        p12Password: config.p12Password,
                        provisionPath: config.provisionURL?.path,
                        entitlementsPath: nil,
                        bundleId: config.options.bundleIdentifier,
                        displayName: config.options.displayName,
                        injectedDylibs: config.dylibsToInject.map { $0.lastPathComponent },
                        logCallback: { log in
                            progress(0.85, log)
                        }
                    )
                } catch {
                    throw IPAError.signingFailed(error.localizedDescription)
                }
                
                // 7. Repack into output IPA using ZipEngine
                progress(0.90, "正在重新压缩打包为 IPA...")
                let outputDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Signed")
                try? fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
                
                let outputName = "\(config.options.displayName ?? appName.replacingOccurrences(of: ".app", with: ""))_signed_\(Int(Date().timeIntervalSince1970)).ipa"
                let outputURL = outputDir.appendingPathComponent(outputName)
                
                do {
                    try ZipEngine.zip(sourceDir: unzippedURL, destinationIPA: outputURL) { pct, msg in
                        progress(0.90 + pct * 0.09, msg)
                    }
                } catch {
                    throw IPAError.archiveFailed(error.localizedDescription)
                }
                
                progress(1.0, "签名打包完成！")
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
