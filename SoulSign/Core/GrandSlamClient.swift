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
            return "苹果服务器返回错误 (\(code)): \(msg)"
        }
    }
}

class GrandSlamClient {
    static let shared = GrandSlamClient()

    private let authURL = URL(string: "https://gsa.apple.com/grandslam/GsService2")!

    func authenticate(
        appleID: String,
        password: String,
        twoFactorCode: String? = nil,
        completion: @escaping (Result<DeveloperSession, AuthError>) -> Void
    ) {
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
                completion(.failure(.networkError("无法打包认证请求")))
                return
            }

            request.httpBody = plistData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(.networkError(error.localizedDescription)))
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    DispatchQueue.main.async {
                        completion(.failure(.networkError("未收到服务器响应")))
                    }
                    return
                }

                guard let responseDict = try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: Any] else {
                    DispatchQueue.main.async {
                        completion(.failure(.networkError("无法解析服务器响应")))
                    }
                    return
                }

                let responseNode = responseDict["Response"] as? [String: Any] ?? [:]
                let statusNode = responseNode["Status"] as? [String: Any] ?? [:]
                let statusCode = statusNode["ec"] as? Int ?? 0

                if statusCode == -22880 || statusCode == -21669 || statusCode == 2011 {
                    DispatchQueue.main.async {
                        completion(.failure(.twoFactorRequired))
                    }
                    return
                }

                if statusCode != 0 {
                    let errorMsg = statusNode["em"] as? String ?? "认证失败"
                    DispatchQueue.main.async {
                        completion(.failure(.appleServerError(statusCode, errorMsg)))
                    }
                    return
                }

                let spsNode = responseNode["sps"] as? [String: Any] ?? [:]
                let token = spsNode["token"] as? String ?? ""

                var cookies: [String: String] = [:]
                if let fields = httpResponse.allHeaderFields as? [String: String],
                   let url = response?.url {
                    let parsedCookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                    for cookie in parsedCookies {
                        cookies[cookie.name] = cookie.value
                    }
                }

                let session = DeveloperSession(
                    appleID: appleID,
                    authToken: token,
                    cookies: cookies,
                    expirationDate: Date().addingTimeInterval(86400 * 7)
                )

                DispatchQueue.main.async {
                    completion(.success(session))
                }
            }.resume()
        }
    }
}
