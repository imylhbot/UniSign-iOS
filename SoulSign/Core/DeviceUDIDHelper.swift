import UIKit

/// Manages device UDID extraction, persistence, and Safari OTA retrieval
class DeviceUDIDHelper {
    private static let udidKey = "SoulSign_CustomUDID"

    /// Gets active device UDID
    static func getDeviceUDID() -> String {
        if let saved = UserDefaults.standard.string(forKey: udidKey), !saved.isEmpty {
            return saved
        }
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
            return vendorID
        }
        return "00008030-001248883652802E"
    }

    /// Sets verified physical UDID
    static func setCustomUDID(_ udid: String) {
        let cleaned = udid.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        UserDefaults.standard.set(cleaned, forKey: udidKey)
    }

    /// Whether current UDID is verified physical hardware UDID
    static func isRealHardwareUDID() -> Bool {
        if let saved = UserDefaults.standard.string(forKey: udidKey), !saved.isEmpty {
            return true
        }
        return false
    }

    /// Copies UDID to clipboard
    static func copyUDIDToClipboard() {
        UIPasteboard.general.string = getDeviceUDID()
    }

    /// Launches Safari to install UDID extraction profile
    static func openUDIDAcquisitionInSafari() {
        LocalInstallServer.shared.installUDIDProfile()
    }
}
