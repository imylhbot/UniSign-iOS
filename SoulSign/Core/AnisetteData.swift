import Foundation
import UIKit

/// Represents Apple Anisette provisioning data required for GrandSlam authentication
public struct AnisetteData: Codable {
    public var machineID: String
    public var oneTimePassword: String
    public var routingInfo: UInt64
    public var clientTimestamp: Date
    public var serialNumber: String
    public var localUserUUID: String

    public init(
        machineID: String = UUID().uuidString.data(using: .utf8)!.base64EncodedString(),
        oneTimePassword: String = UUID().uuidString.data(using: .utf8)!.base64EncodedString(),
        routingInfo: UInt64 = 0x1B1B,
        clientTimestamp: Date = Date(),
        serialNumber: String = "C02SG0000000",
        localUserUUID: String = UUID().uuidString
    ) {
        self.machineID = machineID
        self.oneTimePassword = oneTimePassword
        self.routingInfo = routingInfo
        self.clientTimestamp = clientTimestamp
        self.serialNumber = serialNumber
        self.localUserUUID = localUserUUID
    }

    /// Converts the Anisette data into standard Apple authentication HTTP headers
    public var httpHeaders: [String: String] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timeString = formatter.string(from: clientTimestamp)

        return [
            "X-Apple-I-MD": machineID,
            "X-Apple-I-MD-M": machineID,
            "X-Apple-I-MD-R": String(routingInfo),
            "X-Apple-I-MD-LU": localUserUUID,
            "X-Apple-I-Client-Time": timeString,
            "X-Apple-I-TimeZone": TimeZone.current.identifier,
            "X-Apple-Locale": Locale.current.identifier,
            "X-Apple-I-SRL-NO": serialNumber,
            "User-Agent": "Xcode (com.apple.dt.Xcode/15.4)"
        ]
    }
}

/// Provides Anisette headers locally or from configured remote Anisette servers (SideStore style)
public class AnisetteProvider {
    public static let shared = AnisetteProvider()

    private let userDefaultsKey = "SoulSign_AnisetteServerURL"
    public var customServerURL: String? {
        get { UserDefaults.standard.string(forKey: userDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }

    public func fetchAnisetteHeaders(completion: @escaping ([String: String]) -> Void) {
        // If a remote server is provided (e.g. SideStore provision server), attempt network fetch
        if let serverStr = customServerURL, !serverStr.isEmpty, let url = URL(string: serverStr) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                   !json.isEmpty {
                    DispatchQueue.main.async { completion(json) }
                    return
                }
                // Fallback to local generated headers
                DispatchQueue.main.async {
                    completion(AnisetteData().httpHeaders)
                }
            }.resume()
        } else {
            // Default built-in local Anisette headers
            completion(AnisetteData().httpHeaders)
        }
    }
}
