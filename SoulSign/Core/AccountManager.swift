import Foundation
import Security

class AccountManager {
    static let shared = AccountManager()

    static let maxQuotaPerAccount = 3
    private let accountsKey = "SoulSign_SavedAppleAccounts"
    private let activeAccountKey = "SoulSign_ActiveAppleAccountEmail"

    private var accounts: [AppleAccount] = []
    private let lock = NSLock()

    private init() {
        loadAccounts()
    }

    // MARK: - Account Persistence
    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([AppleAccount].self, from: data) {
            accounts = decoded
        }
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
        NotificationCenter.default.post(name: NSNotification.Name("SoulSignAccountsUpdatedNotification"), object: nil)
    }

    func getAllAccounts() -> [AppleAccount] {
        lock.lock()
        defer { lock.unlock() }
        return accounts
    }

    func getAccount(email: String) -> AppleAccount? {
        lock.lock()
        defer { lock.unlock() }
        return accounts.first { $0.email.lowercased() == email.lowercased() }
    }

    func getActiveAccount() -> AppleAccount? {
        lock.lock()
        defer { lock.unlock() }
        if let active = accounts.first(where: { $0.isActive }) {
            return active
        }
        return accounts.first
    }

    func setActiveAccount(email: String) {
        lock.lock()
        for i in 0..<accounts.count {
            accounts[i].isActive = (accounts[i].email.lowercased() == email.lowercased())
        }
        saveAccounts()
        lock.unlock()
    }

    func addOrUpdateAccount(
        email: String,
        password: String? = nil,
        session: DeveloperSession? = nil,
        teamID: String? = nil,
        teamName: String? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }

        var acc: AppleAccount
        if let idx = accounts.firstIndex(where: { $0.email.lowercased() == email.lowercased() }) {
            acc = accounts[idx]
            if let teamID = teamID { acc.teamID = teamID }
            if let teamName = teamName { acc.teamName = teamName }
            acc.sessionStatus = .valid
            acc.lastCheckedDate = Date()
            accounts[idx] = acc
        } else {
            let isFirst = accounts.isEmpty
            acc = AppleAccount(
                email: email,
                teamID: teamID,
                teamName: teamName,
                isActive: isFirst,
                sessionStatus: .valid,
                lastCheckedDate: Date()
            )
            accounts.append(acc)
        }

        // Store password in Keychain
        if let pwd = password, !pwd.isEmpty {
            saveKeychainPassword(pwd, for: email)
        }

        // Store session in Keychain
        if let session = session {
            saveKeychainSession(session, for: email)
        }

        saveAccounts()
    }

    func updateAccountStatus(email: String, status: SessionStatus, message: String? = nil) {
        lock.lock()
        if let idx = accounts.firstIndex(where: { $0.email.lowercased() == email.lowercased() }) {
            accounts[idx].sessionStatus = status
            accounts[idx].lastCheckedDate = Date()
            accounts[idx].statusMessage = message
            saveAccounts()
        }
        lock.unlock()
    }

    func removeAccount(email: String) {
        lock.lock()
        accounts.removeAll { $0.email.lowercased() == email.lowercased() }
        deleteKeychainData(for: email)
        if !accounts.isEmpty && !accounts.contains(where: { $0.isActive }) {
            accounts[0].isActive = true
        }
        saveAccounts()
        lock.unlock()
    }

    // MARK: - 3-App Quota Enforcement (Strict)
    func activeAppsCount(for email: String) -> Int {
        return AppLibraryStore.shared.activeAppsCount(for: email)
    }

    func remainingQuota(for email: String) -> Int {
        let count = activeAppsCount(for: email)
        return max(0, Self.maxQuotaPerAccount - count)
    }

    func hasReachedQuota(for email: String) -> Bool {
        return activeAppsCount(for: email) >= Self.maxQuotaPerAccount
    }

    /// Checks whether an account has capacity to sign a new app
    func canSignNewApp(email: String, bundleID: String) -> Bool {
        // If the bundle ID is already signed under this email, it's considered an update/renewal
        let existingRecords = AppLibraryStore.shared.records(for: email)
        if existingRecords.contains(where: { $0.bundleID.lowercased() == bundleID.lowercased() }) {
            return true
        }
        return remainingQuota(for: email) > 0
    }

    // MARK: - Keychain Security
    func getPassword(for email: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "pwd_\(email.lowercased())",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }

    func getSession(for email: String) -> DeveloperSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "session_\(email.lowercased())",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let session = try? JSONDecoder().decode(DeveloperSession.self, from: data) {
            return session
        }
        return nil
    }

    private func saveKeychainPassword(_ pwd: String, for email: String) {
        let key = "pwd_\(email.lowercased())"
        let data = pwd.data(using: .utf8)!
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func saveKeychainSession(_ session: DeveloperSession, for email: String) {
        let key = "session_\(email.lowercased())"
        guard let data = try? JSONEncoder().encode(session) else { return }
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychainData(for email: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "pwd_\(email.lowercased())"] as CFDictionary)
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "session_\(email.lowercased())"] as CFDictionary)
    }
}
