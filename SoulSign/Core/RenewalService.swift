import Foundation

/// Orchestrates 1-Click automatic certificate & provisioning renewal
public class RenewalService {
    public static let shared = RenewalService()

    public enum RenewalError: LocalizedError {
        case accountNotFound
        case sessionInvalid
        case noAppsToRenew
        case appNotFound
        case renewalFailed(String)

        public var errorDescription: String? {
            switch self {
            case .accountNotFound: return "未找到绑定的 Apple ID 账号"
            case .sessionInvalid: return "Apple ID 会话已失效，请重新登录"
            case .noAppsToRenew: return "当前账号名下暂无可续签的应用"
            case .appNotFound: return "未找到目标应用记录"
            case .renewalFailed(let msg): return "续签失败: \(msg)"
            }
        }
    }

    /// Renews all apps associated with a specific Apple ID account (1-Click Account Renewal)
    public func renewAppsForAccount(
        email: String,
        progress: @escaping (Int, Int, String) -> Void,
        completion: @escaping (Result<Int, RenewalError>) -> Void
    ) {
        guard let account = AccountManager.shared.getAccount(email: email) else {
            completion(.failure(.accountNotFound))
            return
        }

        guard let session = AccountManager.shared.getSession(for: email) else {
            completion(.failure(.sessionInvalid))
            return
        }

        let apps = AppLibraryStore.shared.records(for: email)
        guard !apps.isEmpty else {
            completion(.failure(.noAppsToRenew))
            return
        }

        let total = apps.count
        var renewedCount = 0
        let deviceUDID = DeviceUDIDHelper.getDeviceUDID()

        func renewNext(index: Int) {
            if index >= total {
                completion(.success(renewedCount))
                return
            }

            var app = apps[index]
            progress(index + 1, total, app.appName)

            ProvisioningService.shared.requestSigningMaterials(
                session: session,
                bundleID: app.bundleID,
                deviceUDID: deviceUDID
            ) { result in
                switch result {
                case .success(let profileData):
                    // Update record expiration
                    app.signedDate = Date()
                    app.expirationDate = Date().addingTimeInterval(86400 * 7)
                    AppLibraryStore.shared.addOrUpdateRecord(app)
                    renewedCount += 1
                    renewNext(index: index + 1)

                case .failure:
                    // Continue with next even if one fails
                    renewNext(index: index + 1)
                }
            }
        }

        renewNext(index: 0)
    }

    /// Renews a single specific app
    public func renewSingleApp(
        bundleID: String,
        completion: @escaping (Result<Void, RenewalError>) -> Void
    ) {
        let allApps = AppLibraryStore.shared.getAllRecords()
        guard var app = allApps.first(where: { $0.bundleID == bundleID }) else {
            completion(.failure(.appNotFound))
            return
        }

        guard let session = AccountManager.shared.getSession(for: app.appleIDEmail) else {
            completion(.failure(.sessionInvalid))
            return
        }

        let deviceUDID = DeviceUDIDHelper.getDeviceUDID()
        ProvisioningService.shared.requestSigningMaterials(
            session: session,
            bundleID: app.bundleID,
            deviceUDID: deviceUDID
        ) { result in
            switch result {
            case .success:
                app.signedDate = Date()
                app.expirationDate = Date().addingTimeInterval(86400 * 7)
                AppLibraryStore.shared.addOrUpdateRecord(app)
                completion(.success(()))

            case .failure(let err):
                completion(.failure(.renewalFailed(err.localizedDescription)))
            }
        }
    }

    /// Renews all apps across all accounts (Global 1-Click Renewal)
    public func renewAllApps(
        progress: @escaping (Int, Int, String) -> Void,
        completion: @escaping (Result<Int, RenewalError>) -> Void
    ) {
        let allApps = AppLibraryStore.shared.getAllRecords()
        guard !allApps.isEmpty else {
            completion(.failure(.noAppsToRenew))
            return
        }

        let total = allApps.count
        var renewed = 0
        let deviceUDID = DeviceUDIDHelper.getDeviceUDID()

        func renewIndex(i: Int) {
            if i >= total {
                completion(.success(renewed))
                return
            }

            var app = allApps[i]
            progress(i + 1, total, app.appName)

            guard let session = AccountManager.shared.getSession(for: app.appleIDEmail) else {
                renewIndex(i: i + 1)
                return
            }

            ProvisioningService.shared.requestSigningMaterials(
                session: session,
                bundleID: app.bundleID,
                deviceUDID: deviceUDID
            ) { result in
                if case .success = result {
                    app.signedDate = Date()
                    app.expirationDate = Date().addingTimeInterval(86400 * 7)
                    AppLibraryStore.shared.addOrUpdateRecord(app)
                    renewed += 1
                }
                renewIndex(i: i + 1)
            }
        }

        renewIndex(i: 0)
    }
}
