import Foundation

/// Lifecycle session status of an Apple Developer Account
enum SessionStatus: String, Codable {
    case valid              // 🟢 Session active & valid
    case expired            // 🔴 Session expired / cookie revoked
    case twoFactorRequired  // 🟡 2FA Challenge pending
    case unchecked          // �?Not checked yet

    var title: String {
        switch self {
        case .valid: return "有效"
        case .expired: return "会话已失�?
        case .twoFactorRequired: return "需 2FA 验证"
        case .unchecked: return "未检�?
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
