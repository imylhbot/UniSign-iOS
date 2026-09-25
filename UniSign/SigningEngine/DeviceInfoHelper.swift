import UIKit

/// Utility to retrieve, display, and manage device UDID
public class DeviceInfoHelper {
    
    private static let customUDIDKey = "SoulSign_CustomUDID"
    private static let legacyUDIDKey = "UniSign_CustomUDID"
    
    /// Retrieves the current device UDID (custom configured, or persistent vendor identifier)
    public static func getDeviceUDID() -> String {
        if let saved = UserDefaults.standard.string(forKey: customUDIDKey), !saved.isEmpty {
            return saved
        }
        if let legacy = UserDefaults.standard.string(forKey: legacyUDIDKey), !legacy.isEmpty {
            return legacy
        }
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
            return vendorID
        }
        return "00008030-001248883652802E"
    }
    
    /// Checks whether the current UDID is verified as a real physical hardware UDID
    public static func isRealHardwareUDID() -> Bool {
        if let saved = UserDefaults.standard.string(forKey: customUDIDKey), !saved.isEmpty {
            return true
        }
        if let legacy = UserDefaults.standard.string(forKey: legacyUDIDKey), !legacy.isEmpty {
            return true
        }
        return false
    }
    
    /// Sets a manual or OTA verified UDID
    public static func setCustomUDID(_ udid: String) {
        let cleaned = udid.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(cleaned, forKey: customUDIDKey)
        UserDefaults.standard.set(cleaned, forKey: legacyUDIDKey)
    }
    
    /// Copies UDID to clipboard
    public static func copyUDIDToClipboard() {
        UIPasteboard.general.string = getDeviceUDID()
    }
    
    /// Starts local server and launches Safari to install the UDID Profile Service (mobileConfigSign mechanism)
    public static func openUDIDAcquisitionInSafari() {
        LocalInstallServer.shared.installUDIDProfile()
    }
    
    /// Opens hosted online UDID retrieval service via Safari
    public static func openOnlineUDIDAcquisition() {
        if let url = URL(string: "https://get.udid.io") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    /// Opens GitHub hosted mobileconfig profile for direct download
    public static func openGitHubMobileConfig() {
        if let url = URL(string: "https://raw.githubusercontent.com/imylhbot/UniSign-iOS/main/ca.mobileconfig") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
