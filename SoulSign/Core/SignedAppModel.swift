import Foundation

/// Record of an installed/signed IPA on the device
public struct SignedAppRecord: Codable, Identifiable, Equatable {
    public var id: String { bundleID }
    public var bundleID: String
    public var appName: String
    public var version: String
    public var signedDate: Date
    public var expirationDate: Date
    public var appleIDEmail: String
    public var ipaPath: String?
    public var iconData: Data?

    public init(
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
    public var remainingDays: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, diff)
    }

    /// Whether the certificate has expired
    public var isExpired: Bool {
        return Date() > expirationDate
    }
}
