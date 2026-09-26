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
            return "Apple ID 鎴栧瘑鐮侀敊璇锛岃锋鏌ヨ緭鍏ャ?
        case .twoFactorRequired:
            return "闇瑕佸弻閲嶈よ?(2FA)銆?
        case .invalid2FACode:
            return "杈撳叆鐨勫弻閲嶉獙璇佺爜鏃犳晥鎴栧凡杩囨湡銆?
        case .sessionExpired:
            return "鐧诲綍浼氳瘽宸茶繃鏈燂紝璇烽噸鏂扮櫥褰曘?
        case .networkError(let msg):
            return "缃戠粶杩炴帴寮傚父: \(msg)"
        case .appleServerError(let code, let msg):
            return "鑻规灉鏈嶅姟鍣ㄨ繑鍥為敊璇?(\(code)): \(msg)"
        }
    }
}

class GrandSlamClient {
    static let shared = GrandSlamClient()

    private let authURL = URL(string: "https://gsa.apple.com/grandslam/GsService2")!

    /// Performs GrandSlam authentication with Apple ID and password
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

            // Inject Anisette Headers
            for (key, value) in anisetteHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }

            // Build GrandSlam Auth Request Plist
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
                completion(.failure(.networkError("鏃犳硶鎵撳寘璁よ瘉璇锋眰")))
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
                        completion(.failure(.networkError("鏈鏀跺埌鏈嶅姟鍣ㄥ搷搴")))
                    }
                    return
                }

                // Parse XML Plist Response
                guard let responseDict = try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: Any] else {
                    DispatchQueue.main.async {
                        completion(.failure(.networkError("鏃犳硶瑙ｆ瀽鏈嶅姟鍣ㄥ搷搴?)))
                    }
                    return
                }

                let responseNode = responseDict["Response"] as? [String: Any] ?? [:]
                let statusNode = responseNode["Status"] as? [String: Any] ?? [:]
                let statusCode = statusNode["ec"] as? Int ?? 0

                // Check for 2FA requirement (ec = -22880 or -21669 or similar 2FA challenge)
                if statusCode == -22880 || statusCode == -21669 || statusCode == 2011 {
                    DispatchQueue.main.async {
                        completion(.failure(.twoFactorRequired))
                    }
                    return
                }

                if statusCode != 0 {
                    let errorMsg = statusNode["em"] as? String ?? "璁よ瘉澶辫触"
                    DispatchQueue.main.async {
                        completion(.failure(.appleServerError(statusCode, errorMsg)))
                    }
                    return
                }

                // Extract spsToken or myacinfo
                let spsNode = responseNode["sps"] as? [String: Any] ?? [:]
                let token = spsNode["token"] as? String ?? ""

                // Extract cookies from HTTP response headers
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
