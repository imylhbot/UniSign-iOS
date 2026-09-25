import Foundation

/// Persistent user preferences for signing configurations and node settings
public class SigningPreferences {
    public static let shared = SigningPreferences()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let selectedNodeIndex = "unisign_selected_node_index"
        static let filenameTemplate = "unisign_filename_template"
        static let compressionLevel = "unisign_compression_level"
        static let autoInstallAfterSigning = "unisign_auto_install"
        static let directInjectPlugin = "unisign_direct_inject"
        static let removeURLSchemes = "unisign_remove_url_schemes"
        static let fixWhiteIcon = "unisign_fix_white_icon"
        static let fixDarkIcon = "unisign_fix_dark_icon"
        static let removeEmbeddedProvision = "unisign_remove_embedded"
        static let removeWatchApp = "unisign_remove_watch"
        static let enableFileSharing = "unisign_enable_file_sharing"
        static let appendSignedSuffix = "unisign_append_signed_suffix"
        static let autoImportDownloadedIPA = "unisign_auto_import"
    }
    
    public var selectedNodeIndex: Int {
        get { defaults.integer(forKey: Keys.selectedNodeIndex) }
        set { defaults.set(newValue, forKey: Keys.selectedNodeIndex) }
    }
    
    public var filenameTemplate: String {
        get { defaults.string(forKey: Keys.filenameTemplate) ?? "[name]_[version]_[timestamp]-UniSign" }
        set { defaults.set(newValue, forKey: Keys.filenameTemplate) }
    }
    
    public var compressionLevel: Int {
        get { defaults.object(forKey: Keys.compressionLevel) != nil ? defaults.integer(forKey: Keys.compressionLevel) : 1 }
        set { defaults.set(newValue, forKey: Keys.compressionLevel) }
    }
    
    public var autoInstallAfterSigning: Bool {
        get { defaults.bool(forKey: Keys.autoInstallAfterSigning) }
        set { defaults.set(newValue, forKey: Keys.autoInstallAfterSigning) }
    }
    
    public var directInjectPlugin: Bool {
        get { defaults.object(forKey: Keys.directInjectPlugin) != nil ? defaults.bool(forKey: Keys.directInjectPlugin) : true }
        set { defaults.set(newValue, forKey: Keys.directInjectPlugin) }
    }
    
    public var directInjection: Bool {
        get { directInjectPlugin }
        set { directInjectPlugin = newValue }
    }
    
    public var removeURLSchemes: Bool {
        get { defaults.bool(forKey: Keys.removeURLSchemes) }
        set { defaults.set(newValue, forKey: Keys.removeURLSchemes) }
    }
    
    public var fixWhiteIcon: Bool {
        get { defaults.bool(forKey: Keys.fixWhiteIcon) }
        set { defaults.set(newValue, forKey: Keys.fixWhiteIcon) }
    }
    
    public var fixDarkIcon: Bool {
        get { defaults.object(forKey: Keys.fixDarkIcon) != nil ? defaults.bool(forKey: Keys.fixDarkIcon) : true }
        set { defaults.set(newValue, forKey: Keys.fixDarkIcon) }
    }
    
    public var removeEmbeddedProvision: Bool {
        get { defaults.bool(forKey: Keys.removeEmbeddedProvision) }
        set { defaults.set(newValue, forKey: Keys.removeEmbeddedProvision) }
    }
    
    public var removeWatchApp: Bool {
        get { defaults.bool(forKey: Keys.removeWatchApp) }
        set { defaults.set(newValue, forKey: Keys.removeWatchApp) }
    }
    
    public var enableFileSharing: Bool {
        get { defaults.object(forKey: Keys.enableFileSharing) != nil ? defaults.bool(forKey: Keys.enableFileSharing) : true }
        set { defaults.set(newValue, forKey: Keys.enableFileSharing) }
    }
    
    public var appendSignedSuffix: Bool {
        get { defaults.object(forKey: Keys.appendSignedSuffix) != nil ? defaults.bool(forKey: Keys.appendSignedSuffix) : true }
        set { defaults.set(newValue, forKey: Keys.appendSignedSuffix) }
    }
    
    public var autoImportDownloadedIPA: Bool {
        get { defaults.object(forKey: Keys.autoImportDownloadedIPA) != nil ? defaults.bool(forKey: Keys.autoImportDownloadedIPA) : true }
        set { defaults.set(newValue, forKey: Keys.autoImportDownloadedIPA) }
    }
    
    public func resetToDefaults() {
        filenameTemplate = "[name]_[version]_[timestamp]-UniSign"
        compressionLevel = 1
        autoInstallAfterSigning = false
        directInjectPlugin = true
        removeURLSchemes = false
        fixWhiteIcon = false
        fixDarkIcon = true
        removeEmbeddedProvision = false
        removeWatchApp = false
        enableFileSharing = true
        appendSignedSuffix = true
        autoImportDownloadedIPA = true
    }
    
    /// Converts current preferences into PlistModifier.CustomizationOptions
    public func makeCustomizationOptions(
        bundleId: String? = nil,
        displayName: String? = nil,
        version: String? = nil,
        minOS: String? = nil
    ) -> PlistModifier.CustomizationOptions {
        return PlistModifier.CustomizationOptions(
            bundleIdentifier: bundleId,
            displayName: displayName,
            versionString: version,
            minimumOSVersion: minOS,
            enableFileSharing: enableFileSharing,
            enableDocumentInPlace: enableFileSharing,
            removeDeviceCapabilities: false,
            removeURLSchemes: removeURLSchemes,
            fixWhiteIcon: fixWhiteIcon,
            fixDarkIcon: fixDarkIcon,
            removeEmbeddedProvision: removeEmbeddedProvision,
            removeWatchApp: removeWatchApp,
            appendSignedSuffix: appendSignedSuffix,
            compressionLevel: compressionLevel,
            filenameTemplate: filenameTemplate
        )
    }
}
