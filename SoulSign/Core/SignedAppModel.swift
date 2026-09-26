import Foundation

/// Record of an installed/signed IPA on the device
struct SignedAppRecord: Codable, Identifiable, Equatable {
    var id: String { bundleID }
    var bundleID: String
    var appName: String
    var version: String
    var signedDate: Date
    var expirationDate: Date
    var appleIDEmail: String
    var ipaPath: String?
    var iconData: Data?

    init(
        bundleID: String,
        appName: String,
        version: String,
        signedDate: Date = Date(),
        expirationDate: Date = Date().addingTimeInterval(86400 * 7),
        appleIDEmail: String,
        ipaPath: String? = nil,
        iconData: Data? = nil
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.version = version
        self.signedDate = signedDate
        self.expirationDate = expirationDate
        self.appleIDEmail = appleIDEmail
        self.ipaPath = ipaPath
        self.iconData = iconData
    }

    /// Remaining valid days (e.g. 7, 6, 5...)
    var remainingDays: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, diff)
    }

    /// Whether the certificate has expired
    var isExpired: Bool {
        return Date() > expirationDate
    }
}
