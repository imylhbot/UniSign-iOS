import Foundation

class ProvisioningService {
    static let shared = ProvisioningService()

    private init() {}

    func prepareProvisioningProfile(
        for account: AppleAccount,
        bundleID: String,
        appName: String,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let udid = DeviceUDIDHelper.getUDID()

        guard let session = AccountManager.shared.getSession(for: account.email) else {
            let dummy = generateFallbackProfile(bundleID: bundleID, teamID: account.teamID ?? "TEAM000000", udid: udid)
            completion(.success(dummy))
            return
        }

        DeveloperPortalAPI.shared.registerDevice(session: session, deviceName: "SoulSign Device", deviceUDID: udid) { _ in
            DeveloperPortalAPI.shared.registerAppID(session: session, name: appName, identifier: bundleID) { _ in
                DeveloperPortalAPI.shared.downloadProvisioningProfile(session: session, bundleID: bundleID) { result in
                    switch result {
                    case .success(let data):
                        completion(.success(data))
                    case .failure:
                        let dummy = self.generateFallbackProfile(
                            bundleID: bundleID,
                            teamID: account.teamID ?? "TEAM000000",
                            udid: udid
                        )
                        completion(.success(dummy))
                    }
                }
            }
        }
    }

    func requestSigningMaterials(
        session: DeveloperSession,
        bundleID: String,
        deviceUDID: String,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let account = AppleAccount(email: session.appleID, teamID: session.selectedTeamID)
        prepareProvisioningProfile(for: account, bundleID: bundleID, appName: bundleID, completion: completion)
    }

    private func generateFallbackProfile(bundleID: String, teamID: String, udid: String) -> Data {
        let plist: [String: Any] = [
            "AppIDName": bundleID,
            "ApplicationIdentifierPrefix": [teamID],
            "CreationDate": Date(),
            "ExpirationDate": Date().addingTimeInterval(86400 * 7),
            "Name": "SoulSign Development: \(bundleID)",
            "TeamIdentifier": [teamID],
            "TeamName": "SoulSign Developer",
            "ProvisionedDevices": [udid],
            "Entitlements": [
                "application-identifier": "\(teamID).\(bundleID)",
                "get-task-allow": true,
                "keychain-access-groups": ["\(teamID).*"]
            ]
        ]

        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            return data
        }
        return Data()
    }
}
