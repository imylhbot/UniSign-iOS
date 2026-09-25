import Foundation

/// Service handling 1-click renewal for Apple ID signed applications
public class RenewalService {
    public static let shared = RenewalService()
    
    public enum RenewalError: LocalizedError {
        case recordNotFound
        case notAnAppleIDApp
        case associatedAccountNotFound(String)
        case renewalFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .recordNotFound: return "Signed app record was not found."
            case .notAnAppleIDApp: return "This application was not signed with an Apple ID."
            case .associatedAccountNotFound(let email): return "Associated Apple ID (\(email)) is no longer saved. Please log in again."
            case .renewalFailed(let msg): return "Renewal failed: \(msg)"
            }
        }
    }
    
    /// Convenience 1-click renewal without progress closure
    public func renewSignedApp(_ record: SignedAppRecord, completion: @escaping (Result<SignedAppRecord, Error>) -> Void) {
        renewApp(record: record, progress: { _, _ in }, completion: completion)
    }
    
    /// Executes silent re-signing to refresh the 7-day expiration window
    public func renewApp(
        record: SignedAppRecord,
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<SignedAppRecord, Error>) -> Void
    ) {
        guard record.signMethod == "apple_id" else {
            completion(.failure(RenewalError.notAnAppleIDApp))
            return
        }
        
        guard let email = record.appleIDEmail else {
            completion(.failure(RenewalError.associatedAccountNotFound("Unknown")))
            return
        }
        
        guard let account = AppleAccountManager.shared.getAllAccounts().first(where: { $0.email.lowercased() == email.lowercased() }) else {
            completion(.failure(RenewalError.associatedAccountNotFound(email)))
            return
        }
        
        progress(0.2, "Authenticating with Apple ID: \(email)...")
        AppleDeveloperService.shared.authenticate(
            appleID: account.email,
            password: account.password
        ) { authResult in
            switch authResult {
            case .failure(let err):
                completion(.failure(RenewalError.renewalFailed("Apple auth failed: \(err.localizedDescription)")))
            case .success:
                progress(0.4, "Requesting renewed provisioning profile...")
                let deviceUDID = DeviceInfoHelper.getDeviceUDID()
                AppleDeveloperService.shared.requestSigningMaterials(
                    bundleID: record.bundleId,
                    deviceUDID: deviceUDID
                ) { signMatResult in
                    switch signMatResult {
                    case .failure(let err):
                        completion(.failure(RenewalError.renewalFailed("Certificate request error: \(err.localizedDescription)")))
                    case .success(let materials):
                        progress(0.6, "Executing re-signature...")
                        let ipaURL = AppLibraryManager.shared.signedDir.appendingPathComponent(record.fileName)
                        
                        let config = IPAManager.SignConfig(
                            ipaURL: ipaURL,
                            p12URL: materials.p12URL,
                            p12Password: "",
                            provisionURL: materials.provisionURL,
                            options: PlistModifier.CustomizationOptions(
                                bundleIdentifier: record.bundleId,
                                displayName: record.name,
                                versionString: record.version
                            )
                        )
                        
                        IPAManager.processAndSign(config: config, progress: { pct, msg in
                            progress(0.6 + pct * 0.35, msg)
                        }) { result in
                            switch result {
                            case .failure(let err):
                                completion(.failure(RenewalError.renewalFailed(err.localizedDescription)))
                            case .success(let newIPAURL):
                                var updatedRecord = record
                                updatedRecord.signedDate = Date()
                                updatedRecord.expiryDate = Date().addingTimeInterval(7 * 24 * 3600)
                                updatedRecord.fileName = newIPAURL.lastPathComponent
                                AppLibraryManager.shared.recordSignedApp(updatedRecord)
                                
                                progress(1.0, "Renewal Complete!")
                                completion(.success(updatedRecord))
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Batch renews all Apple ID signed apps sequentially
    public func renewAllSignedApps(
        progress: @escaping (Int, Int, String) -> Void,
        completion: @escaping ([SignedAppRecord], [String]) -> Void
    ) {
        let apps = AppLibraryManager.shared.getSignedApps().filter { $0.signMethod == "apple_id" }
        guard !apps.isEmpty else {
            completion([], [])
            return
        }
        
        var renewed: [SignedAppRecord] = []
        var failures: [String] = []
        
        func processNext(index: Int) {
            if index >= apps.count {
                DispatchQueue.main.async {
                    completion(renewed, failures)
                }
                return
            }
            let app = apps[index]
            DispatchQueue.main.async {
                progress(index + 1, apps.count, "正在续签 (\(index + 1)/\(apps.count)): \(app.name)...")
            }
            renewApp(record: app, progress: { _, _ in }) { res in
                switch res {
                case .success(let updated):
                    renewed.append(updated)
                case .failure(let err):
                    failures.append("\(app.name): \(err.localizedDescription)")
                }
                processNext(index: index + 1)
            }
        }
        processNext(index: 0)
    }
    
    /// Automatically renews any app that will expire within given hours (default 24h / 1 day)
    public func autoRenewExpiringAppsIfNeeded(withinHours: Int = 24, completion: (([SignedAppRecord]) -> Void)? = nil) {
        let apps = AppLibraryManager.shared.getSignedApps().filter { $0.signMethod == "apple_id" }
        let threshold = Date().addingTimeInterval(TimeInterval(withinHours * 3600))
        let expiringApps = apps.filter { $0.expiryDate <= threshold }
        guard !expiringApps.isEmpty else {
            completion?([])
            return
        }
        
        var renewed: [SignedAppRecord] = []
        func processNext(index: Int) {
            if index >= expiringApps.count {
                DispatchQueue.main.async {
                    completion?(renewed)
                }
                return
            }
            let app = expiringApps[index]
            renewApp(record: app, progress: { _, _ in }) { res in
                if case .success(let updated) = res {
                    renewed.append(updated)
                }
                processNext(index: index + 1)
            }
        }
        processNext(index: 0)
    }
}
