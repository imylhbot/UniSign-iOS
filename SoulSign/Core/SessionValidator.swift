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
            completion(.unchecked, "未找到账�?)
            return
        }

        guard let session = AccountManager.shared.getSession(for: email) else {
            // No stored session, check if we have password to re-authenticate
            if AccountManager.shared.getPassword(for: email) != nil {
                AccountManager.shared.updateAccountStatus(email: email, status: .twoFactorRequired, message: "需重新认证")
                completion(.twoFactorRequired, "缺少有效会话凭据")
            } else {
                AccountManager.shared.updateAccountStatus(email: email, status: .expired, message: "请重新输入密码登�?)
                completion(.expired, "未保存会�?)
            }
            return
        }

        // Test session against Developer Portal
        DeveloperPortalAPI.shared.listTeams(session: session) { result in
            switch result {
            case .success(let teams):
                let teamInfo = teams.first?.name ?? "个人开发�?
                AccountManager.shared.updateAccountStatus(
                    email: email,
                    status: .valid,
                    message: "已连�?(\(teamInfo))"
                )
                completion(.valid, "会话正常，支持签�?)

            case .failure(let error):
                let errorDesc = error.localizedDescription
                // Determine whether it's 2FA, expired, or network issue
                let status: SessionStatus
                if errorDesc.contains("2011") || errorDesc.contains("2FA") {
                    status = .twoFactorRequired
                } else if errorDesc.contains("1100") || errorDesc.contains("失效") || errorDesc.contains("expired") || errorDesc.contains("401") {
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
