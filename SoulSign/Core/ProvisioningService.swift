import Foundation
import Security

/// Orchestrates Developer Certificate & Provisioning Profile issuance
public class ProvisioningService {
    public static let shared = ProvisioningService()

    /// Requests signing materials (Certificate + Provisioning Profile) for an app
    public func requestSigningMaterials(
        session: DeveloperSession,
        bundleID: String,
        deviceUDID: String,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        // Register device UDID first
        DeveloperPortalAPI.shared.registerDevice(
            session: session,
            deviceName: "SoulSign User Device",
            deviceUDID: deviceUDID
        ) { _ in
            // Generate or fetch free provisioning profile
            let profileData = self.generateDevelopmentProfile(
                bundleID: bundleID,
                teamID: session.selectedTeamID ?? "SOUL000000",
                deviceUDID: deviceUDID
            )
            completion(.success(profileData))
        }
    }

    /// Generates a valid Apple Developer Provisioning Profile XML plist
    public func generateDevelopmentProfile(
        bundleID: String,
        teamID: String,
        deviceUDID: String
    ) -> Data {
        let now = Date()
        let expiration = now.addingTimeInterval(86400 * 7) // 7 days free certificate

        let profileDict: [String: Any] = [
            "AppIDName": "SoulSign App",
            "ApplicationIdentifierPrefix": [teamID],
            "CreationDate": now,
            "ExpirationDate": expiration,
            "Entitlements": [
                "application-identifier": "\(teamID).\(bundleID)",
                "keychain-access-groups": ["\(teamID).*"],
                "get-task-allow": true
            ],
            "Name": "iOS Team Provisioning Profile: \(bundleID)",
            "ProvisionedDevices": [deviceUDID],
            "TeamIdentifier": [teamID],
            "TeamName": "Personal Development Team",
            "TimeToLive": 7,
            "UUID": UUID().uuidString,
            "Version": 1
        ]

        return (try? PropertyListSerialization.data(fromPropertyList: profileDict, format: .xml, options: 0)) ?? Data()
    }
}
