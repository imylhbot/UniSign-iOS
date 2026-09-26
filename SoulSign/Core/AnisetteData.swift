import Foundation
import UIKit

struct AnisetteData: Codable {
    var machineID: String
    var oneTimePassword: String
    var routingInfo: UInt64
    var clientTimestamp: Date
    var serialNumber: String
    var localUserUUID: String

    init(
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

    var httpHeaders: [String: String] {
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

class AnisetteProvider {
    static let shared = AnisetteProvider()

    private let userDefaultsKey = "SoulSign_AnisetteServerURL"
    static let defaultServerURL = "https://ani.sidestore.io"

    var serverURL: String {
        if let custom = UserDefaults.standard.string(forKey: userDefaultsKey), !custom.isEmpty {
            return custom
        }
        return Self.defaultServerURL
    }

    var customServerURL: String? {
        get { UserDefaults.standard.string(forKey: userDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }

    func fetchAnisetteHeaders(completion: @escaping ([String: String]) -> Void) {
        let endpoint = serverURL
        AppLogger.shared.log("正在从 Anisette 服务器 (\(endpoint)) 获取硬件特征头...", category: .auth)

        if let url = URL(string: endpoint) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            request.setValue("SoulSign-iOS/2.5.0", forHTTPHeaderField: "User-Agent")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                   !json.isEmpty {
                    AppLogger.shared.log("成功获取远程 Anisette 特征头 (\(json.count) 项)", category: .auth)
                    DispatchQueue.main.async { completion(json) }
                    return
                }

                if let error = error {
                    AppLogger.shared.log("远程 Anisette 请求失败 (\(error.localizedDescription))，使用本地降级特征", category: .auth)
                } else {
                    AppLogger.shared.log("远程 Anisette 响应无效，使用本地降级特征", category: .auth)
                }

                DispatchQueue.main.async {
                    completion(AnisetteData().httpHeaders)
                }
            }.resume()
        } else {
            completion(AnisetteData().httpHeaders)
        }
    }
}
