import Foundation

struct DeveloperSession: Codable {
    var appleID: String
    var authToken: String
    var cookies: [String: String]
    var expirationDate: Date
    var selectedTeamID: String?

    init(
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

struct DeveloperTeam: Codable {
    var teamID: String
    var name: String
    var status: String
    var type: String
}

class DeveloperPortalAPI {
    static let shared = DeveloperPortalAPI()

    private let baseURL = "https://developerservices2.apple.com/services/QH65B2"

    private func buildRequest(action: String, session: DeveloperSession, body: [String: Any]) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/\(action)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20.0
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Accept")
        request.setValue("Xcode (com.apple.dt.Xcode/15.4)", forHTTPHeaderField: "User-Agent")

        if !session.authToken.isEmpty {
            request.setValue(session.authToken, forHTTPHeaderField: "X-Apple-GS-Token")
        }

        let cookieString = session.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        if !cookieString.isEmpty {
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        }

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

    func listTeams(
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

    func registerDevice(
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
            DispatchQueue.main.async { completion(.success(())) }
        }.resume()
    }

    func registerAppID(
        session: DeveloperSession,
        name: String,
        identifier: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "name": name,
            "identifier": identifier
        ]

        guard let request = buildRequest(action: "addAppId.action", session: session, body: body) else {
            completion(.failure(AuthError.networkError("无法构建 App ID 注册请求")))
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            DispatchQueue.main.async { completion(.success(identifier)) }
        }.resume()
    }

    func downloadProvisioningProfile(
        session: DeveloperSession,
        bundleID: String,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "appIdId": bundleID
        ]

        guard let request = buildRequest(action: "downloadProvisioningProfile.action", session: session, body: body) else {
            completion(.failure(AuthError.networkError("无法构建描述文件下载请求")))
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            if let data = data, !data.isEmpty {
                DispatchQueue.main.async { completion(.success(data)) }
            } else {
                DispatchQueue.main.async { completion(.failure(AuthError.networkError("获取描述文件为空"))) }
            }
        }.resume()
    }
}
