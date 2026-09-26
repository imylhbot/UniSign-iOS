import Foundation

/// Lifecycle session status of an Apple Developer Account
public enum SessionStatus: String, Codable {
    case valid              // 🟢 Session active & valid
    case expired            // 🔴 Session expired / cookie revoked
    case twoFactorRequired  // 🟡 2FA Challenge pending
    case unchecked          // ⚪ Not checked yet

    public var title: String {
        switch self {
        case .valid: return "有效"
        case .expired: return "会话已失效"
        case .twoFactorRequired: return "需 2FA 验证"
        case .unchecked: return "未检测"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .valid: return "#28C840"           // Green
        case .expired: return "#FF3B30"         // Red
        case .twoFactorRequired: return "#FF9500" // Orange
        case .unchecked: return "#8E8E93"       // Gray
        }
    }
}

/// Represents a configured Apple Developer Account in SoulSign
public struct AppleAccount: Codable, Identifiable, Equatable {
    public var id: String { email }
    public var email: String
    public var teamID: String?
    public var teamName: String?
    public var isActive: Bool
    public var addedDate: Date
    public var sessionStatus: SessionStatus
    public var lastCheckedDate: Date?
    public var statusMessage: String?

    public init(
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

    public static func == (lhs: AppleAccount, rhs: AppleAccount) -> Bool {
        return lhs.email == rhs.email
    }
}
