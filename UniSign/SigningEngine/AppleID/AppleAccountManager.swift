import Foundation

public struct AppleAccount: Codable, Identifiable, Equatable {
    public let id: String
    public var email: String
    public var password: String
    public var teamID: String?
    public var teamName: String?
    public var lastUsedDate: Date
    public var isActive: Bool
    
    public init(
        id: String = UUID().uuidString,
        email: String,
        password: String,
        teamID: String? = nil,
        teamName: String? = nil,
        lastUsedDate: Date = Date(),
        isActive: Bool = false
    ) {
        self.id = id
        self.email = email
        self.password = password
        self.teamID = teamID
        self.teamName = teamName
        self.lastUsedDate = lastUsedDate
        self.isActive = isActive
    }
}

/// Manages multiple Apple ID accounts, persistence, active account selection, and 3-app quota tracking
public class AppleAccountManager {
    public static let shared = AppleAccountManager()
    
    private let storageKey = "UniSign_SavedAppleAccounts"
    private var accounts: [AppleAccount] = []
    public static let maxAppsPerAppleID: Int = 3
    
    public init() {
        loadAccounts()
    }
    
    public func getAllAccounts() -> [AppleAccount] {
        return accounts
    }
    
    public func getActiveAccount() -> AppleAccount? {
        return accounts.first(where: { $0.isActive }) ?? accounts.first
    }
    
    public func addOrUpdateAccount(_ account: AppleAccount) {
        if let idx = accounts.firstIndex(where: { $0.email.lowercased() == account.email.lowercased() }) {
            accounts[idx] = account
        } else {
            var newAcc = account
            if accounts.isEmpty {
                newAcc.isActive = true
            }
            accounts.append(newAcc)
        }
        saveAccounts()
    }
    
    public func setActiveAccount(id: String) {
        for i in 0..<accounts.count {
            accounts[i].isActive = (accounts[i].id == id)
            if accounts[i].id == id {
                accounts[i].lastUsedDate = Date()
            }
        }
        saveAccounts()
    }
    
    public func removeAccount(id: String) {
        accounts.removeAll(where: { $0.id == id })
        if let first = accounts.first, !accounts.contains(where: { $0.isActive }) {
            accounts[0].isActive = true
        }
        saveAccounts()
    }
    
    // MARK: - Quota & App Tracking (3 Apps Limit)
    
    /// Returns the active number of apps signed by this specific Apple ID
    public func activeAppsCount(for email: String) -> Int {
        return signedApps(for: email).filter { !$0.isExpired }.count
    }
    
    /// Returns all apps signed with this Apple ID
    public func signedApps(for email: String) -> [SignedAppRecord] {
        return AppLibraryManager.shared.getSignedApps().filter {
            $0.appleIDEmail?.lowercased() == email.lowercased()
        }
    }
    
    /// Checks if the Apple ID has reached Apple's 3-app free sideloading limit
    public func hasReachedQuota(for email: String) -> Bool {
        return activeAppsCount(for: email) >= AppleAccountManager.maxAppsPerAppleID
    }
    
    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AppleAccount].self, from: data) {
            self.accounts = decoded
        }
    }
    
    private func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
