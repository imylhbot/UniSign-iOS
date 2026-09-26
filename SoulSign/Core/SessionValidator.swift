import Foundation

/// Active health checker for Apple Developer sessions
class SessionValidator {
    static let shared = SessionValidator()

    /// Checks the login validity of a specific Apple Account by querying Developer Portal
    func checkValidity(
        for email: String,
        completion: @escaping (SessionStatus, String) -> Void
    ) {
        guard let account = AccountManager.shared.getAccount(email: email) else {
            completion(.unchecked, "鏈鎵惧埌璐﹀?)
            return
        }

        guard let session = AccountManager.shared.getSession(for: email) else {
            // No stored session, check if we have password to re-authenticate
            if AccountManager.shared.getPassword(for: email) != nil {
                AccountManager.shared.updateAccountStatus(email: email, status: .twoFactorRequired, message: "闇閲嶆柊璁よ瘉")
                completion(.twoFactorRequired, "缂哄皯鏈夋晥浼氳瘽鍑鎹")
            } else {
                AccountManager.shared.updateAccountStatus(email: email, status: .expired, message: "璇烽噸鏂拌緭鍏ュ瘑鐮佺櫥褰?)
                completion(.expired, "鏈淇濆瓨浼氳?)
            }
            return
        }

        // Test session against Developer Portal
        DeveloperPortalAPI.shared.listTeams(session: session) { result in
            switch result {
            case .success(let teams):
                let teamInfo = teams.first?.name ?? "涓浜哄紑鍙戣?
                AccountManager.shared.updateAccountStatus(
                    email: email,
                    status: .valid,
                    message: "宸茶繛鎺?(\(teamInfo))"
                )
                completion(.valid, "浼氳瘽姝ｅ父锛屾敮鎸佺惧?)

            case .failure(let error):
                let errorDesc = error.localizedDescription
                // Determine whether it's 2FA, expired, or network issue
                let status: SessionStatus
                if errorDesc.contains("2011") || errorDesc.contains("2FA") {
                    status = .twoFactorRequired
                } else if errorDesc.contains("1100") || errorDesc.contains("澶辨晥") || errorDesc.contains("expired") || errorDesc.contains("401") {
                    status = .expired
                } else {
                    status = .expired
                }

                AccountManager.shared.updateAccountStatus(
                    email: email,
                    status: status,
                    message: errorDesc
                )
                completion(status, errorDesc)
            }
        }
    }

    /// Checks validity of all saved accounts in parallel
    func checkAllAccounts(completion: @escaping ([String: SessionStatus]) -> Void) {
        let accounts = AccountManager.shared.getAllAccounts()
        guard !accounts.isEmpty else {
            completion([:])
            return
        }

        var results: [String: SessionStatus] = [:]
        let group = DispatchGroup()

        for acc in accounts {
            group.enter()
            checkValidity(for: acc.email) { status, _ in
                results[acc.email] = status
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }
}
