import UIKit

class DeviceUDIDHelper {
    private static let udidKey = "SoulSign_DeviceUDID"
    static let customUDIDURL = "https://udid.192688.xyz/"

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
        AppLogger.shared.log("已更新硬件 UDID: \(trimmed)", category: .server)
        NotificationCenter.default.post(name: NSNotification.Name("SoulSignUDIDUpdatedNotification"), object: nil)
    }

    static var hasConfiguredUDID: Bool {
        guard let saved = UserDefaults.standard.string(forKey: udidKey), !saved.isEmpty else {
            return false
        }
        return true
    }

    static func copyUDIDToClipboard() {
        let udid = getDeviceUDID()
        UIPasteboard.general.string = udid
        AppLogger.shared.log("已复制 UDID 到剪贴板: \(udid)", category: .server)
    }

    static func openUDIDAcquisitionInSafari() {
        AppLogger.shared.log("正在打开指定 UDID 获取网站: \(customUDIDURL)", category: .server)
        if let url = URL(string: customUDIDURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    static func openMobileConfigEnrollment() {
        openUDIDAcquisitionInSafari()
    }
}
