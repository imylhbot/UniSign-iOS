import UIKit

/// Utility to retrieve, display, and manage device UDID
public class DeviceInfoHelper {
    
    private static let customUDIDKey = "UniSign_CustomUDID"
    
    /// Retrieves the current device UDID (custom configured, or persistent vendor identifier)
    public static func getDeviceUDID() -> String {
        if let saved = UserDefaults.standard.string(forKey: customUDIDKey), !saved.isEmpty {
            return saved
        }
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
            let formatted = vendorID.replacingOccurrences(of: "-", with: "").lowercased()
            return formatted
        }
        return "00008030-001248883652802e"
    }
    
    /// Sets a manual UDID (e.g. copied from Safari mobileprovision extraction or iTunes)
    public static func setCustomUDID(_ udid: String) {
        UserDefaults.standard.set(udid.trimmingCharacters(in: .whitespacesAndNewlines), forKey: customUDIDKey)
    }
    
    /// Copies UDID to clipboard
    public static func copyUDIDToClipboard() {
        UIPasteboard.general.string = getDeviceUDID()
    }
}
