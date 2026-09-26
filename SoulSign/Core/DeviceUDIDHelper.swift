import UIKit

class DeviceUDIDHelper {
    private static let udidKey = "SoulSign_DeviceUDID"

    static func getUDID() -> String {
        if let saved = UserDefaults.standard.string(forKey: udidKey), !saved.isEmpty {
            return saved
        }
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv.replacingOccurrences(of: "-", with: "")
        }
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    static func getDeviceUDID() -> String {
        return getUDID()
    }

    static func setCustomUDID(_ udid: String) {
        let trimmed = udid.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: udidKey)
    }

    static var hasConfiguredUDID: Bool {
        guard let saved = UserDefaults.standard.string(forKey: udidKey), !saved.isEmpty else {
            return false
        }
        return true
    }

    static func copyUDIDToClipboard() {
        UIPasteboard.general.string = getDeviceUDID()
    }

    static func openUDIDAcquisitionInSafari() {
        LocalInstallServer.shared.installUDIDProfile()
    }

    static func openMobileConfigEnrollment() {
        if let url = URL(string: "https://udid.tech") {
            UIApplication.shared.open(url)
        }
    }
}
