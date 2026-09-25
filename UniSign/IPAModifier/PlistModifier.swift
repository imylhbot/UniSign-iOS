import Foundation

/// Modifies Info.plist properties of an iOS App bundle
public class PlistModifier {
    
    public struct CustomizationOptions {
        public var bundleIdentifier: String?
        public var displayName: String?
        public var versionString: String?
        public var buildNumber: String?
        public var minimumOSVersion: String?
        public var enableFileSharing: Bool
        public var enableDocumentInPlace: Bool
        public var removeDeviceCapabilities: Bool
        public var removeURLSchemes: Bool
        public var fixWhiteIcon: Bool
        public var fixDarkIcon: Bool
        public var removeEmbeddedProvision: Bool
        public var removeWatchApp: Bool
        public var appendSignedSuffix: Bool
        public var compressionLevel: Int // 0: 快速, 1: 标准, 2: 最高
        public var filenameTemplate: String
        public var customKeys: [String: Any]
        
        public init(
            bundleIdentifier: String? = nil,
            displayName: String? = nil,
            versionString: String? = nil,
            buildNumber: String? = nil,
            minimumOSVersion: String? = nil,
            enableFileSharing: Bool = false,
            enableDocumentInPlace: Bool = false,
            removeDeviceCapabilities: Bool = false,
            removeURLSchemes: Bool = false,
            fixWhiteIcon: Bool = false,
            fixDarkIcon: Bool = false,
            removeEmbeddedProvision: Bool = false,
            removeWatchApp: Bool = false,
            appendSignedSuffix: Bool = true,
            compressionLevel: Int = 1,
            filenameTemplate: String = "[name]_[version]_[timestamp]-UniSign",
            customKeys: [String: Any] = [:]
        ) {
            self.bundleIdentifier = bundleIdentifier
            self.displayName = displayName
            self.versionString = versionString
            self.buildNumber = buildNumber
            self.minimumOSVersion = minimumOSVersion
            self.enableFileSharing = enableFileSharing
            self.enableDocumentInPlace = enableDocumentInPlace
            self.removeDeviceCapabilities = removeDeviceCapabilities
            self.removeURLSchemes = removeURLSchemes
            self.fixWhiteIcon = fixWhiteIcon
            self.fixDarkIcon = fixDarkIcon
            self.removeEmbeddedProvision = removeEmbeddedProvision
            self.removeWatchApp = removeWatchApp
            self.appendSignedSuffix = appendSignedSuffix
            self.compressionLevel = compressionLevel
            self.filenameTemplate = filenameTemplate
            self.customKeys = customKeys
        }
        
        // MARK: - Compatibility Aliases
        public var newBundleID: String? {
            get { bundleIdentifier }
            set { bundleIdentifier = newValue }
        }
        public var newDisplayName: String? {
            get { displayName }
            set { displayName = newValue }
        }
        public var newVersion: String? {
            get { versionString }
            set { versionString = newValue }
        }
        public var newMinimumOSVersion: String? {
            get { minimumOSVersion }
            set { minimumOSVersion = newValue }
        }
        public var enableOpeningDocumentsInPlace: Bool {
            get { enableDocumentInPlace }
            set { enableDocumentInPlace = newValue }
        }
    }
    
    public enum PlistError: LocalizedError {
        case fileNotFound
        case deserializationFailed
        case serializationFailed
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound: return "Info.plist file not found at the specified path."
            case .deserializationFailed: return "Failed to deserialize Info.plist data."
            case .serializationFailed: return "Failed to serialize modified Info.plist data."
            }
        }
    }
    
    /// Reads and returns the Info.plist dictionary from the app directory
    public static func readPlist(at appURL: URL) throws -> [String: Any] {
        let plistURL = appURL.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw PlistError.fileNotFound
        }
        let data = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw PlistError.deserializationFailed
        }
        return plist
    }
    
    /// Applies customization options to the Info.plist in the target app bundle
    public static func apply(options: CustomizationOptions, toAppURL appURL: URL) throws {
        let plistURL = appURL.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw PlistError.fileNotFound
        }
        
        let data = try Data(contentsOf: plistURL)
        var format: PropertyListSerialization.PropertyListFormat = .binary
        guard var dict = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] else {
            throw PlistError.deserializationFailed
        }
        
        // 1. Bundle Identifier
        if let newID = options.bundleIdentifier, !newID.trimmingCharacters(in: .whitespaces).isEmpty {
            dict["CFBundleIdentifier"] = newID
        }
        
        // 2. Display Name
        if let newName = options.displayName, !newName.trimmingCharacters(in: .whitespaces).isEmpty {
            dict["CFBundleDisplayName"] = newName
            dict["CFBundleName"] = newName
        }
        
        // 3. Version string & Build number
        if let version = options.versionString, !version.trimmingCharacters(in: .whitespaces).isEmpty {
            dict["CFBundleShortVersionString"] = version
        }
        if let build = options.buildNumber, !build.trimmingCharacters(in: .whitespaces).isEmpty {
            dict["CFBundleVersion"] = build
        }
        
        // 4. Minimum OS Version
        if let minOS = options.minimumOSVersion, !minOS.trimmingCharacters(in: .whitespaces).isEmpty {
            dict["MinimumOSVersion"] = minOS
        }
        
        // 5. File access permissions (Files.app integration)
        if options.enableFileSharing {
            dict["UIFileSharingEnabled"] = true
        }
        if options.enableDocumentInPlace {
            dict["LSSupportsOpeningDocumentsInPlace"] = true
        }
        
        // 6. Device capability bypass (e.g. remove ARKit, metal, telephony limits)
        if options.removeDeviceCapabilities {
            dict.removeValue(forKey: "UIRequiredDeviceCapabilities")
        }
        
        // 7. Remove URL Schemes (Avoid hijacking other apps)
        if options.removeURLSchemes {
            dict.removeValue(forKey: "CFBundleURLTypes")
        }
        
        // 8. Fix White Icon (Rewrite CFBundleIcons primary icon references)
        if options.fixWhiteIcon {
            var iconsDict = (dict["CFBundleIcons"] as? [String: Any]) ?? [:]
            var primaryDict = (iconsDict["CFBundlePrimaryIcon"] as? [String: Any]) ?? [:]
            if primaryDict["CFBundleIconFiles"] == nil {
                primaryDict["CFBundleIconFiles"] = ["AppIcon", "AppIcon60x60"]
            }
            iconsDict["CFBundlePrimaryIcon"] = primaryDict
            dict["CFBundleIcons"] = iconsDict
        }
        
        // 9. Fix Dark Icon (Ensure CFBundleIcons supports iOS 18 dark theme)
        if options.fixDarkIcon {
            dict["UIUserInterfaceStyle"] = "Automatic"
        }
        
        // 10. Custom keys
        for (key, val) in options.customKeys {
            dict[key] = val
        }
        
        // Write back as XML or Binary Plist
        let updatedData = try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0)
        try updatedData.write(to: plistURL, options: .atomic)
    }
    
    /// Formats the output IPA filename based on template tags and DateFormatter tokens
    public static func formatOutputFilename(
        template: String,
        appName: String,
        bundleId: String,
        version: String,
        displayName: String?,
        appendSignedSuffix: Bool
    ) -> String {
        var result = template.isEmpty ? "[name]_[version]_[timestamp]-UniSign" : template
        
        let now = Date()
        let timestamp = "\(Int(now.timeIntervalSince1970))"
        let dName = (displayName != nil && !displayName!.isEmpty) ? displayName! : appName
        
        // Tag replacements
        result = result.replacingOccurrences(of: "[name]", with: appName)
        result = result.replacingOccurrences(of: "[displayName]", with: dName)
        result = result.replacingOccurrences(of: "[version]", with: version)
        result = result.replacingOccurrences(of: "[identifier]", with: bundleId)
        result = result.replacingOccurrences(of: "[bundleId]", with: bundleId)
        result = result.replacingOccurrences(of: "[timestamp]", with: timestamp)
        
        // Regex / token replacement for {...} DateFormatter
        let datePattern = "\\{([^\\}]+)\\}"
        if let regex = try? NSRegularExpression(pattern: datePattern, options: []) {
            let nsStr = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let formatRange = match.range(at: 1)
                let dateFormat = nsStr.substring(with: formatRange)
                let df = DateFormatter()
                df.dateFormat = dateFormat
                let dateStr = df.string(from: now)
                result = (result as NSString).replacingCharacters(in: match.range, with: dateStr)
            }
        }
        
        if appendSignedSuffix && !result.hasSuffix("-signed") && !result.hasSuffix("-UniSign") {
            result += "-signed"
        }
        
        // Clean characters safe for iOS filenames
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\":<>")
        result = result.components(separatedBy: invalidChars).joined(separator: "_")
        
        if !result.hasSuffix(".ipa") {
            result += ".ipa"
        }
        return result
    }
}
