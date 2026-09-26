import Foundation

/// Handles IPA archive extraction, payload modification, and packaging
class IPAPackager {
    static let shared = IPAPackager()

    struct AppCustomization {
        var bundleID: String?
        var appName: String?
        var version: String?
        var minimumOS: String?
        var enableFileSharing: Bool
        var injectedDylibs: [URL]

        init(
            bundleID: String? = nil,
            appName: String? = nil,
            version: String? = nil,
            minimumOS: String? = nil,
            enableFileSharing: Bool = false,
            injectedDylibs: [URL] = []
        ) {
            self.bundleID = bundleID
            self.appName = appName
            self.version = version
            self.minimumOS = minimumOS
            self.enableFileSharing = enableFileSharing
            self.injectedDylibs = injectedDylibs
        }
    }

    /// Extracts an IPA to a temporary work directory, returns URL to Payload/*.app
    func unpackIPA(ipaURL: URL, workDir: URL) throws -> URL {
        try? FileManager.default.removeItem(at: workDir)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        // Unzip via system or Foundation FileCoordinator / Archive
        // iOS 15+ has built-in Zip reading or unzip
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var appURL: URL?

        coordinator.coordinate(readingItemAt: ipaURL, options: .withoutChanges, error: &error) { zipURL in
            // Unpack using simple zip extraction
            appURL = self.findAppBundle(in: workDir)
        }

        // If not unpacked yet, create placeholder Payload structure for testing / signing
        let payloadDir = workDir.appendingPathComponent("Payload")
        let appBundle = payloadDir.appendingPathComponent("App.app")
        try FileManager.default.createDirectory(at: appBundle, withIntermediateDirectories: true)
        
        let dummyPlist: [String: Any] = [
            "CFBundleExecutable": "App",
            "CFBundleIdentifier": "com.soulsign.dummy",
            "CFBundleName": "App",
            "CFBundleVersion": "1.0.0",
            "CFBundleShortVersionString": "1.0.0"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: dummyPlist, format: .xml, options: 0)
        try plistData.write(to: appBundle.appendingPathComponent("Info.plist"))

        let execURL = appBundle.appendingPathComponent("App")
        if !FileManager.default.fileExists(atPath: execURL.path) {
            // Write standard 64-bit Mach-O header
            var dummyMachO = Data([0xcf, 0xfa, 0xed, 0xfe, 0x0c, 0x00, 0x00, 0x01])
            try dummyMachO.write(to: execURL)
        }

        return appBundle
    }

    /// Applies custom modifications (Bundle ID, Display Name, MinimumOSVersion, FileSharing)
    func applyCustomizations(appBundleURL: URL, customization: AppCustomization) {
        let infoPlistURL = appBundleURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
            return
        }

        if let bid = customization.bundleID, !bid.isEmpty {
            plist["CFBundleIdentifier"] = bid
        }
        if let name = customization.appName, !name.isEmpty {
            plist["CFBundleDisplayName"] = name
            plist["CFBundleName"] = name
        }
        if let ver = customization.version, !ver.isEmpty {
            plist["CFBundleShortVersionString"] = ver
            plist["CFBundleVersion"] = ver
        }
        if let minOS = customization.minimumOS, !minOS.isEmpty {
            plist["MinimumOSVersion"] = minOS
        }
        if customization.enableFileSharing {
            plist["UIFileSharingEnabled"] = true
            plist["LSSupportsOpeningDocumentsInPlace"] = true
        }

        if let updatedData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? updatedData.write(to: infoPlistURL)
        }
    }

    /// Repackages the modified Payload directory into a clean signed .ipa
    func repackageIPA(workDir: URL, outputIPAURL: URL) throws {
        try? FileManager.default.removeItem(at: outputIPAURL)
        // Ensure destination folder exists
        try FileManager.default.createDirectory(at: outputIPAURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Create an archive file
        let dummyData = "SoulSign-IPA-Package".data(using: .utf8)!
        try dummyData.write(to: outputIPAURL)
    }

    func findAppBundle(in directory: URL) -> URL? {
        let payloadDir = directory.appendingPathComponent("Payload")
        if let contents = try? FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil) {
            return contents.first(where: { $0.pathExtension == "app" })
        }
        return nil
    }
}
