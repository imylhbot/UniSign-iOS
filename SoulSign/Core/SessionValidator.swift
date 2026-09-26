import Foundation

class SessionValidator {
    static let shared = SessionValidator()

    private init() {}

    func validateAccount(
        _ account: AppleAccount,
        completion: @escaping (SessionStatus, String?) -> Void
    ) {
        AppLogger.shared.log("正在探测账号会话状态: \(account.email)", category: .portal)

        guard let session = AccountManager.shared.getSession(for: account.email) else {
            AccountManager.shared.updateAccountStatus(
                email: account.email,
                status: .expired,
                message: "未找到会话凭据，请重新登录"
            )
            AppLogger.shared.log("账号 \(account.email) 缺少会话凭据", category: .portal)
            completion(.expired, "未找到会话凭据")
            return
        }

        if session.expirationDate < Date() {
            AccountManager.shared.updateAccountStatus(
                email: account.email,
                status: .expired,
                message: "会话已过期，请重新登录"
            )
            AppLogger.shared.log("账号 \(account.email) 会话过期", category: .portal)
            completion(.expired, "会话已过期")
            return
        }

        DeveloperPortalAPI.shared.listTeams(session: session) { result in
            switch result {
            case .success(let teams):
                let teamName = teams.first?.name ?? account.teamName
                let teamID = teams.first?.teamID ?? account.teamID
                AccountManager.shared.addOrUpdateAccount(
                    email: account.email,
                    session: session,
                    teamID: teamID,
                    teamName: teamName
                )
                AccountManager.shared.updateAccountStatus(
                    email: account.email,
                    status: .valid,
                    message: "会话有效"
                )
                AppLogger.shared.log("账号 \(account.email) 会话有效 (团队: \(teamName ?? "个人"))", category: .portal)
                completion(.valid, nil)

            case .failure(let error):
                let errMsg = error.localizedDescription
                let status: SessionStatus
                if errMsg.lowercased().contains("2fa") || errMsg.contains("两步") || errMsg.contains("两步验证") {
                    status = .twoFactorRequired
                } else {
                    status = .expired
                }
                AccountManager.shared.updateAccountStatus(
                    email: account.email,
                    status: status,
                    message: errMsg
                )
                AppLogger.shared.log("账号 \(account.email) 探测结果: \(status.title) (\(errMsg))", category: .portal)
                completion(status, errMsg)
            }
        }
    }

    func validateAllAccounts(completion: @escaping ([String: SessionStatus]) -> Void) {
        let accounts = AccountManager.shared.getAllAccounts()
        guard !accounts.isEmpty else {
            completion([:])
            return
        }

        var results: [String: SessionStatus] = [:]
        let group = DispatchGroup()

        for account in accounts {
            group.enter()
            validateAccount(account) { status, _ in
                results[account.email] = status
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }
}
