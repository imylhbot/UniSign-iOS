import Foundation

public struct DeveloperSession: Codable {
    public var appleID: String
    public var authToken: String
    public var cookies: [String: String]
    public var expirationDate: Date
    public var selectedTeamID: String?

    public init(
        appleID: String,
        authToken: String,
        cookies: [String: String],
        expirationDate: Date = Date().addingTimeInterval(86400 * 7),
        selectedTeamID: String? = nil
    ) {
        self.appleID = appleID
        self.authToken = authToken
        self.cookies = cookies
        self.expirationDate = expirationDate
        self.selectedTeamID = selectedTeamID
    }
}

public struct DeveloperTeam: Codable {
    public var teamID: String
    public var name: String
    public var status: String
    public var type: String
}

public class DeveloperPortalAPI {
    public static let shared = DeveloperPortalAPI()

    private let baseURL = "https://developerservices2.apple.com/services/QH65B2"

    /// Builds standard Developer Portal request with session cookies and tokens
    private func buildRequest(action: String, session: DeveloperSession, body: [String: Any]) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/\(action)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15.0
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Accept")
        request.setValue("Xcode (com.apple.dt.Xcode/15.4)", forHTTPHeaderField: "User-Agent")

        if !session.authToken.isEmpty {
            request.setValue(session.authToken, forHTTPHeaderField: "X-Apple-GS-Token")
        }

        // Set Cookie header
        let cookieString = session.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        if !cookieString.isEmpty {
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        }

        // Add clientId & protocolVersion
        var finalBody = body
        finalBody["clientId"] = "XABBG36SBA"
        finalBody["protocolVersion"] = "QH65B2"
        if let teamID = session.selectedTeamID {
            finalBody["teamId"] = teamID
        }

        if let data = try? PropertyListSerialization.data(fromPropertyList: finalBody, format: .xml, options: 0) {
            request.httpBody = data
        }

        return request
    }

    /// Fetches development teams for the given session (also serves as session validity probe)
    public func listTeams(
        session: DeveloperSession,
        completion: @escaping (Result<[DeveloperTeam], Error>) -> Void
    ) {
        guard let request = buildRequest(action: "listTeams.action", session: session, body: [:]) else {
            completion(.failure(AuthError.networkError("无法构建团队查询请求")))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data,
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(AuthError.networkError("解析团队列表失败")))
                }
                return
            }

            let resultCode = plist["resultCode"] as? Int ?? -1
            if resultCode != 0 {
                let userString = plist["userString"] as? String ?? "开发者会话已失效 (\(resultCode))"
                DispatchQueue.main.async {
                    completion(.failure(AuthError.appleServerError(resultCode, userString)))
                }
                return
            }

            var teams: [DeveloperTeam] = []
            if let teamList = plist["teams"] as? [[String: Any]] {
                for item in teamList {
                    let tid = item["teamId"] as? String ?? ""
                    let name = item["name"] as? String ?? tid
                    let status = item["status"] as? String ?? "active"
                    let type = item["type"] as? String ?? "Company/Organization"
                    if !tid.isEmpty {
                        teams.append(DeveloperTeam(teamID: tid, name: name, status: status, type: type))
                    }
                }
            }

            DispatchQueue.main.async { completion(.success(teams)) }
        }.resume()
    }

    /// Registers a device UDID to the developer team
    public func registerDevice(
        session: DeveloperSession,
        deviceName: String,
        deviceUDID: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "name": deviceName,
            "deviceNumber": deviceUDID
        ]

        guard let request = buildRequest(action: "addDevice.action", session: session, body: body) else {
            completion(.failure(AuthError.networkError("无法构建设备注册请求")))
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            // Device registered or already present
            DispatchQueue.main.async { completion(.success(())) }
        }.resume()
    }
}
