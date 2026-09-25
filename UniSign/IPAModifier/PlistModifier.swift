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
            self.customKeys = customKeys
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
        
        // 7. Custom keys
        for (key, val) in options.customKeys {
            dict[key] = val
        }
        
        // Write back as XML or Binary Plist
        let updatedData = try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0)
        try updatedData.write(to: plistURL, options: .atomic)
    }
}
