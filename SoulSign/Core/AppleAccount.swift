import Foundation

/// Lifecycle session status of an Apple Developer Account
enum SessionStatus: String, Codable {
    case valid              // 馃煝 Session active & valid
    case expired            // 馃敶 Session expired / cookie revoked
    case twoFactorRequired  // 馃煛 2FA Challenge pending
    case unchecked          // 鈿?Not checked yet

    var title: String {
        switch self {
        case .valid: return "鏈夋晥"
        case .expired: return "浼氳瘽宸插け鏁?
        case .twoFactorRequired: return "闇 2FA 楠岃瘉"
        case .unchecked: return "鏈妫娴?
        }
    }

    var badgeColorHex: String {
        switch self {
        case .valid: return "#28C840"           // Green
        case .expired: return "#FF3B30"         // Red
        case .twoFactorRequired: return "#FF9500" // Orange
        case .unchecked: return "#8E8E93"       // Gray
        }
    }
}

/// Represents a configured Apple Developer Account in SoulSign
struct AppleAccount: Codable, Identifiable, Equatable {
    var id: String { email }
    var email: String
    var teamID: String?
    var teamName: String?
    var isActive: Bool
    var addedDate: Date
    var sessionStatus: SessionStatus
    var lastCheckedDate: Date?
    var statusMessage: String?

    init(
        email: String,
        teamID: String? = nil,
        teamName: String? = nil,
        isActive: Bool = false,
        addedDate: Date = Date(),
        sessionStatus: SessionStatus = .unchecked,
        lastCheckedDate: Date? = nil,
        statusMessage: String? = nil
    ) {
        self.email = email
        self.teamID = teamID
        self.teamName = teamName
        self.isActive = isActive
        self.addedDate = addedDate
        self.sessionStatus = sessionStatus
        self.lastCheckedDate = lastCheckedDate
        self.statusMessage = statusMessage
    }

    static func == (lhs: AppleAccount, rhs: AppleAccount) -> Bool {
        return lhs.email == rhs.email
    }
}
