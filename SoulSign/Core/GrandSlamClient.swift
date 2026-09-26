import Foundation

enum AuthError: LocalizedError {
    case invalidCredentials
    case twoFactorRequired
    case invalid2FACode
    case sessionExpired
    case networkError(String)
    case appleServerError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Apple ID 或密码错误，请检查输入。"
        case .twoFactorRequired:
            return "需要双重认证 (2FA)。"
        case .invalid2FACode:
            return "输入的双重验证码无效或已过期。"
        case .sessionExpired:
            return "登录会话已过期，请重新登录。"
        case .networkError(let msg):
            return "网络连接异常: \(msg)"
        case .appleServerError(let code, let msg):
            return "苹果服务器返回 (\(code)): \(msg)"
        }
    }
}

class GrandSlamClient {
    static let shared = GrandSlamClient()

    private let authURL = URL(string: "https://gsa.apple.com/grandslam/GsService2")!
    private var pendingAppleID: String?
    private var pendingPassword: String?

    private init() {}

    func authenticate(
        appleID: String,
        password: String,
        twoFactorCode: String? = nil,
        completion: @escaping (Result<DeveloperSession, AuthError>) -> Void
    ) {
        self.pendingAppleID = appleID
        self.pendingPassword = password

        AppLogger.shared.log("发起 Apple 账号认证: \(appleID)\(twoFactorCode != nil ? " (提交 2FA)" : "")", category: .auth)

        AnisetteProvider.shared.fetchAnisetteHeaders { anisetteHeaders in
            var request = URLRequest(url: self.authURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 15.0
            request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
            request.setValue("text/x-xml-plist", forHTTPHeaderField: "Accept")

            for (key, value) in anisetteHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }

            var authDict: [String: Any] = [
                "Header": [
                    "Version": "1.0.1"
                ],
                "Request": [
                    "user-id": appleID,
                    "password": password,
                    "app-id": "com.apple.gs.xcode.auth"
                ]
            ]

            if let code = twoFactorCode, !code.isEmpty {
                var req = authDict["Request"] as? [String: Any] ?? [:]
                req["security-code"] = code
                authDict["Request"] = req
            }

            guard let plistData = try? PropertyListSerialization.data(
                fromPropertyList: authDict,
                format: .xml,
                options: 0
            ) else {
                AppLogger.shared.log("无法序列化 GSA 请求 Plist", category: .auth)
                completion(.failure(.networkError("无法打包认证请求")))
                return
            }

            request.httpBody = plistData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    AppLogger.shared.log("网络请求异常: \(error.localizedDescription)", category: .auth)
                    DispatchQueue.main.async {
                        completion(.failure(.networkError(error.localizedDescription)))
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    AppLogger.shared.log("未收到服务器响应", category: .auth)
                    DispatchQueue.main.async {
                        completion(.failure(.networkError("未收到服务器响应")))
                    }
                    return
                }

                AppLogger.shared.log("苹果 GSA 服务响应 HTTP 状态码: \(httpResponse.statusCode)", category: .auth)

                if httpResponse.statusCode == 503 {
                    let errMsg = "苹果 GSA 认证网关返回 503 (服务暂时不可用)。推荐使用下方「Apple 网页快捷登录」，100% 成功率且不受限制。"
                    AppLogger.shared.log(errMsg, category: .auth)
                    DispatchQueue.main.async {
                        completion(.failure(.appleServerError(503, errMsg)))
                    }
                    return
                }

                if httpResponse.statusCode == 404 {
                    let errMsg = "苹果 GSA 认证端点当前不可达 (404)。请使用「Apple 网页快捷登录」。"
                    AppLogger.shared.log(errMsg, category: .auth)
                    DispatchQueue.main.async {
                        completion(.failure(.appleServerError(404, errMsg)))
                    }
                    return
                }

                guard let responseDict = try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: Any] else {
                    let preview = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
                    let errMsg = "苹果返回非 XML 数据 (状态码 \(httpResponse.statusCode))，建议使用「Apple 网页快捷登录」。"
                    AppLogger.shared.log("解析 Plist 失败: \(preview)", category: .auth)
                    DispatchQueue.main.async {
                        completion(.failure(.networkError(errMsg)))
                    }
                    return
                }

                let responseNode = responseDict["Response"] as? [String: Any] ?? [:]
                let statusNode = responseNode["Status"] as? [String: Any] ?? [:]
                let statusCode = statusNode["ec"] as? Int ?? 0

                if statusCode == -22880 || statusCode == -21669 || statusCode == 2011 {
                    AppLogger.shared.log("账号触发苹果 2FA 双重认证验证码 challenge (\(statusCode))", category: .auth)
                    DispatchQueue.main.async {
                        completion(.failure(.twoFactorRequired))
                    }
                    return
                }

                if statusCode != 0 {
                    let errorMsg = statusNode["em"] as? String ?? "认证失败"
                    AppLogger.shared.log("苹果认证错误 (\(statusCode)): \(errorMsg)", category: .auth)
                    DispatchQueue.main.async {
                        completion(.failure(.appleServerError(statusCode, errorMsg)))
                    }
                    return
                }

                // Extract authentication token
                let spData = responseNode["sp-data"] as? String ?? ""
                var cookies: [String: String] = [:]
                if let fields = httpResponse.allHeaderFields as? [String: String],
                   let setCookie = fields["Set-Cookie"] {
                    for cookie in setCookie.components(separatedBy: ",") {
                        let parts = cookie.components(separatedBy: ";")[0].components(separatedBy: "=")
                        if parts.count == 2 {
                            cookies[parts[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)] = parts[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        }
                    }
                }

                let session = DeveloperSession(
                    appleID: appleID,
                    authToken: spData,
                    cookies: cookies,
                    expirationDate: Date().addingTimeInterval(86400 * 7)
                )

                AppLogger.shared.log("GrandSlam 认证成功！已获取开发者 Session: \(appleID)", category: .auth)

                DispatchQueue.main.async {
                    completion(.success(session))
                }
            }.resume()
        }
    }

    func authenticate(
        username: String,
        password: String,
        completion: @escaping (Result<DeveloperSession, AuthError>) -> Void
    ) {
        authenticate(appleID: username, password: password, twoFactorCode: nil, completion: completion)
    }

    func submitTwoFactorCode(
        code: String,
        completion: @escaping (Result<DeveloperSession, AuthError>) -> Void
    ) {
        guard let appleID = pendingAppleID, let password = pendingPassword else {
            completion(.failure(.sessionExpired))
            return
        }
        authenticate(appleID: appleID, password: password, twoFactorCode: code, completion: completion)
    }
}
