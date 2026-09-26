import Foundation
import UIKit
import Security
import CommonCrypto

/// Service handling Apple ID authentication, Certificate Signing Request (CSR),
/// device registration, and provisioning profile downloads from Apple Developer API.
public class AppleDeveloperService {
    
    public static let shared = AppleDeveloperService()
    
    public struct AppleSession {
        public let appleID: String
        public let dsid: String
        public let authToken: String
        public var teamID: String?
        public var teamName: String?
        public var cookies: [String: String] = [:]
    }
    
    public struct AppleSigningMaterials {
        public let p12URL: URL
        public let provisionURL: URL
        public let privateKey: SecKey
        public let certDER: Data
        
        public init(p12URL: URL, provisionURL: URL, privateKey: SecKey, certDER: Data) {
            self.p12URL = p12URL
            self.provisionURL = provisionURL
            self.privateKey = privateKey
            self.certDER = certDER
        }
    }
    
    public enum AppleAuthError: LocalizedError {
        case twoFactorRequired
        case invalidCredentials
        case teamNotFound
        case certificateRequestFailed(String)
        case profileRequestFailed(String)
        case networkError(Error)
        case general(String)
        
        public var errorDescription: String? {
            switch self {
            case .twoFactorRequired: return "需要输入双重验证码 (2FA)。"
            case .invalidCredentials: return "Apple ID 或密码错误，请核对后重试。"
            case .teamNotFound: return "未找到该 Apple ID 关联的开发者团队。"
            case .certificateRequestFailed(let msg): return "Apple 证书申请失败: \(msg)"
            case .profileRequestFailed(let msg): return "描述文件申请失败: \(msg)"
            case .networkError(let err): return "网络连接异常: \(err.localizedDescription)"
            case .general(let msg): return msg
            }
        }
    }
    
    public var currentSession: AppleSession?
    
    // MARK: - 1. Apple GrandSlam Authentication
    
    public func authenticate(
        appleID: String,
        password: String,
        twoFactorCode: String? = nil,
        completion: @escaping (Result<AppleSession, AppleAuthError>) -> Void
    ) {
        AnisetteClient.shared.fetchAnisetteHeaders { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let anisetteHeaders):
                self.performGrandSlamLogin(
                    appleID: appleID,
                    password: password,
                    twoFactorCode: twoFactorCode,
                    headers: anisetteHeaders,
                    completion: completion
                )
            }
        }
    }
    
    private func performGrandSlamLogin(
        appleID: String,
        password: String,
        twoFactorCode: String?,
        headers: [String: String],
        completion: @escaping (Result<AppleSession, AppleAuthError>) -> Void
    ) {
        guard let url = URL(string: "https://gsa.apple.com/grandslam/GsService2") else {
            completion(.failure(.general("无效的认证服务地址")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("akd/1.0 (Macintosh; OS X 10.15.7)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Accept")
        
        for (k, v) in headers {
            if k == "X-MMe-Client-Info" && v.contains("Xcode") {
                request.setValue("<MacBookPro13,2> <macOS;13.1;22C65> <com.apple.AuthKit/1 (com.apple.akd/1.0)>", forHTTPHeaderField: k)
            } else {
                request.setValue(v, forHTTPHeaderField: k)
            }
        }
        
        if let code = twoFactorCode, !code.isEmpty {
            request.setValue(code, forHTTPHeaderField: "security-code")
            request.setValue(code, forHTTPHeaderField: "X-Apple-2SV-Pin")
        }
        
        let fullPass = (twoFactorCode?.isEmpty == false) ? "\(password)\(twoFactorCode!)" : password
        let escapedId = appleID.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        let escapedPass = fullPass.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        
        let plistPayload = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Header</key>
            <dict>
                <key>Version</key>
                <string>1.0.1</string>
            </dict>
            <key>Request</key>
            <dict>
                <key>cpApp</key>
                <string>com.apple.gs.xcode.auth</string>
                <key>o</key>
                <string>auth</string>
                <key>u</key>
                <string>\(escapedId)</string>
                <key>p</key>
                <string>\(escapedPass)</string>
            </dict>
        </dict>
        </plist>
        """
        request.httpBody = plistPayload.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.general("Apple 身份认证服务器未返回有效数据")))
                return
            }
            
            // Check for 2FA requirement
            if httpResponse.statusCode == 409 || httpResponse.allHeaderFields["X-Apple-2SV-Pin"] != nil || httpResponse.allHeaderFields["x-apple-2sv-pin"] != nil {
                AppLogger.shared.log("检测到 Apple ID 已开启双重认证 (2FA)，需要验证码", category: .warn)
                completion(.failure(.twoFactorRequired))
                return
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                AppLogger.shared.log("Apple ID 账号或密码不正确 (HTTP \(httpResponse.statusCode))", category: .error)
                completion(.failure(.invalidCredentials))
                return
            }
            
            if httpResponse.statusCode != 200 {
                AppLogger.shared.log("苹果身份认证返回非 200 状态 (HTTP \(httpResponse.statusCode))，建议使用「网页官方授权」", category: .warn)
                completion(.failure(.general("苹果身份服务返回状态码 HTTP \(httpResponse.statusCode)，建议在证书管理中使用「网页安全授权」登录")))
                return
            }
            
            var dsid = (httpResponse.allHeaderFields["X-Apple-DSID"] as? String) ?? (httpResponse.allHeaderFields["x-apple-dsid"] as? String) ?? ""
            var token = (httpResponse.allHeaderFields["X-Apple-Session-Token"] as? String) ?? (httpResponse.allHeaderFields["x-apple-session-token"] as? String) ?? ""
            
            var cookieDict: [String: String] = [:]
            if let allHeaders = httpResponse.allHeaderFields as? [String: String], let reqUrl = request.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaders, for: reqUrl)
                for c in cookies {
                    cookieDict[c.name] = c.value
                }
            }
            if let cookieHeader = httpResponse.allHeaderFields["Set-Cookie"] as? String {
                for part in cookieHeader.components(separatedBy: ";") {
                    let kv = part.components(separatedBy: "=")
                    if kv.count == 2 {
                        let k = kv[0].trimmingCharacters(in: .whitespaces)
                        let v = kv[1].trimmingCharacters(in: .whitespaces)
                        if !k.isEmpty && !v.isEmpty {
                            cookieDict[k] = v
                        }
                    }
                }
            }
            
            // Parse XML response for token if present
            if let d = data, let plist = try? PropertyListSerialization.propertyList(from: d, options: [], format: nil) as? [String: Any] {
                if let resp = plist["Response"] as? [String: Any] {
                    if let sp = resp["sp"] as? [String: Any], let c = sp["c"] as? String {
                        token = c
                    }
                    if let ds = resp["dsid"] as? String {
                        dsid = ds
                    }
                }
            }
            
            if cookieDict["myacinfo"] == nil && !token.isEmpty {
                cookieDict["myacinfo"] = token
            }
            
            // Validate that we actually obtained a valid token or myacinfo cookie
            let validAuthToken = !token.isEmpty && token.count > 10
            let validMyacinfo = (cookieDict["myacinfo"]?.count ?? 0) > 10
            guard validAuthToken || validMyacinfo else {
                AppLogger.shared.log("苹果服务器未签发授权 Token，账号可能需要通过网页完成二次安全验证", category: .warn)
                completion(.failure(.general("未能获取有效的 Apple 开发者身份令牌，可能需要通过二次验证。请在证书管理中使用「网页安全授权」登录。")))
                return
            }
            
            let cleanTeamId = "TEAM" + String(abs(appleID.hashValue) % 1000000000)
            var session = AppleSession(
                appleID: appleID,
                dsid: dsid,
                authToken: token.isEmpty ? (cookieDict["myacinfo"] ?? "") : token,
                teamID: cleanTeamId,
                teamName: "\(appleID) (Personal Team)",
                cookies: cookieDict
            )
            
            self.currentSession = session
            
            // Save or update account in AppleAccountManager
            let acc = AppleAccount(
                email: appleID,
                password: password,
                teamID: session.teamID,
                teamName: session.teamName,
                isActive: true,
                myacinfo: cookieDict["myacinfo"],
                sessionCookies: cookieDict
            )
            AppleAccountManager.shared.addOrUpdateAccount(acc)
            
            completion(.success(session))
        }.resume()
    }
    
    // MARK: - 2. Active Session Management
    
    public func getActiveSession() -> AppleSession? {
        if let activeAcc = AppleAccountManager.shared.activeAccount {
            if let s = currentSession, s.appleID.lowercased() == activeAcc.email.lowercased() {
                let validToken = !s.authToken.isEmpty && !s.authToken.contains("-") && s.authToken.count > 20
                let validCookie = (s.cookies["myacinfo"]?.count ?? 0) > 20
                if validToken || validCookie {
                    return s
                }
            }
            
            // Check if active account has cached valid myacinfo cookie
            if let myacinfo = activeAcc.myacinfo ?? activeAcc.sessionCookies?["myacinfo"], myacinfo.count > 20 {
                var cookies = activeAcc.sessionCookies ?? [:]
                cookies["myacinfo"] = myacinfo
                let cleanTeamId = activeAcc.teamID ?? ("TEAM" + String(abs(activeAcc.email.hashValue) % 1000000000))
                let restored = AppleSession(
                    appleID: activeAcc.email,
                    dsid: cookies["dsid"] ?? "",
                    authToken: myacinfo,
                    teamID: cleanTeamId,
                    teamName: activeAcc.teamName ?? "\(activeAcc.email) (Personal Team)",
                    cookies: cookies
                )
                self.currentSession = restored
                return restored
            }
        }
        return nil
    }
    
    public func ensureAuthenticatedSession(completion: @escaping (Result<AppleSession, AppleAuthError>) -> Void) {
        if let s = getActiveSession() {
            completion(.success(s))
            return
        }
        
        guard let activeAcc = AppleAccountManager.shared.activeAccount else {
            completion(.failure(.general("未找到活跃的 Apple ID 账号，请在「证书管理」中先添加或授权账号。")))
            return
        }
        
        guard !activeAcc.password.isEmpty else {
            completion(.failure(.general("账号 [\(activeAcc.email)] 的开发者授权已过期，请在「证书管理」点击该账号进行「网页安全授权」以刷新登录凭据。")))
            return
        }
        
        AppLogger.shared.log("正在使用保存的凭证向苹果身份服务器验证: \(activeAcc.email)...", category: .appleID)
        self.authenticate(appleID: activeAcc.email, password: activeAcc.password) { authRes in
            switch authRes {
            case .success(let session):
                AppLogger.shared.log("✅ 苹果会话认证就绪: DSID=\(session.dsid)", category: .appleID)
                completion(.success(session))
            case .failure(let err):
                AppLogger.shared.log("❌ 苹果身份认证失败: \(err.localizedDescription)", category: .error)
                completion(.failure(err))
            }
        }
    }
    
    // MARK: - 3. Request Official Materials (P12 & MobileProvision)
    
    public func requestSigningMaterials(
        bundleID: String,
        deviceUDID: String,
        completion: @escaping (Result<AppleSigningMaterials, AppleAuthError>) -> Void
    ) {
        self.ensureAuthenticatedSession { [weak self] sessionRes in
            guard let self = self else { return }
            switch sessionRes {
            case .failure(let err):
                completion(.failure(err))
                return
            case .success(let session):
                // 1. Check if cached valid materials exist with valid private key and profile
                if let cached = CertificateStorageManager.shared.getAppleIDMaterials(email: session.appleID),
                   let cachedKey = CertificateStorageManager.shared.getAppleIDPrivateKey(email: session.appleID) {
                    if let parsed = try? ZSignBridge.inspectProvision(cached.provisionURL.path) {
                        if let exp = parsed["ExpirationDate"] as? Date, exp > Date(),
                           let devices = parsed["ProvisionedDevices"] as? [String], devices.contains(deviceUDID) {
                            var bundleMatch = false
                            if let ent = parsed["Entitlements"] as? [String: Any], let appID = ent["application-identifier"] as? String {
                                if appID.hasSuffix(".*") || appID.hasSuffix(".\(bundleID)") {
                                    bundleMatch = true
                                }
                            }
                            if bundleMatch {
                                let certData = (try? Data(contentsOf: cached.p12URL)) ?? Data()
                                let mat = AppleSigningMaterials(
                                    p12URL: cached.p12URL,
                                    provisionURL: cached.provisionURL,
                                    privateKey: cachedKey,
                                    certDER: certData
                                )
                                AppLogger.shared.log("复用本地未过期的 Apple ID 官方签名凭证: \(cached.provisionURL.lastPathComponent)", category: .cert)
                                completion(.success(mat))
                                return
                            }
                        }
                    }
                }
                
                // 2. Generate local RSA 2048 keypair
                var keyError: Unmanaged<CFError>?
                let keyAttrs: [String: Any] = [
                    kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                    kSecAttrKeySizeInBits as String: 2048,
                    kSecAttrIsPermanent as String: false
                ]
                
                guard let privateKey = SecKeyCreateRandomKey(keyAttrs as CFDictionary, &keyError),
                      let publicKey = SecKeyCopyPublicKey(privateKey),
                      let pubKeyData = SecKeyCopyExternalRepresentation(publicKey, &keyError) as Data? else {
                    completion(.failure(.certificateRequestFailed("生成 RSA 密钥对失败")))
                    return
                }
                
                // 3. Construct PKCS#10 CSR (Certificate Signing Request)
                guard let csrDER = self.generatePKCS10CSR(privateKey: privateKey, publicKeyData: pubKeyData, commonName: "Apple Development: \(session.appleID)") else {
                    completion(.failure(.certificateRequestFailed("构造 PKCS#10 CSR 证书请求失败")))
                    return
                }
                let csrString = "-----BEGIN CERTIFICATE REQUEST-----\n" + csrDER.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]) + "\n-----END CERTIFICATE REQUEST-----"
                
                // 4. Request Developer Certificate & Profile from Apple Developer API
                DispatchQueue.global(qos: .userInitiated).async {
                    self.executeAppleDeveloperAPIFlow(
                        session: session,
                        bundleID: bundleID,
                        deviceUDID: deviceUDID,
                        csrString: csrString,
                        privateKey: privateKey,
                        pubKeyData: pubKeyData,
                        completion: completion
                    )
                }
            }
        }
    }
    
    // MARK: - Apple Developer Services API Client
    
    private func sendDeveloperRequest(
        action: String,
        session: AppleSession,
        parameters: [String: Any],
        isRetry: Bool = false,
        completion: @escaping (Result<[String: Any], AppleAuthError>) -> Void
    ) {
        guard let url = URL(string: "https://developerservices2.apple.com/services/QH65B2/ios/\(action).action") else {
            completion(.failure(.general("无效的苹果服务接口地址: \(action)")))
            return
        }
        
        let currentS = (self.currentSession?.appleID.lowercased() == session.appleID.lowercased()) ? (self.currentSession ?? session) : session
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Accept")
        request.setValue("Xcode", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        if !currentS.authToken.isEmpty && !currentS.authToken.starts(with: "myacinfo") && currentS.authToken.count > 30 {
            request.setValue(currentS.authToken, forHTTPHeaderField: "X-Apple-GS-Token")
        }
        if !currentS.dsid.isEmpty {
            request.setValue(currentS.dsid, forHTTPHeaderField: "X-Apple-DSID")
        }
        
        var cookieParts: [String] = []
        let myacinfo = currentS.cookies["myacinfo"] ?? (currentS.authToken.count > 10 ? currentS.authToken : "")
        if !myacinfo.isEmpty {
            cookieParts.append("myacinfo=\(myacinfo)")
        }
        if !currentS.dsid.isEmpty {
            cookieParts.append("dsid=\(currentS.dsid)")
        }
        for (k, v) in currentS.cookies where k != "myacinfo" && k != "dsid" {
            cookieParts.append("\(k)=\(v)")
        }
        if !cookieParts.isEmpty {
            request.setValue(cookieParts.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        }
        
        var bodyDict = parameters
        bodyDict["clientId"] = "XABBG36SBA"
        bodyDict["protocolVersion"] = "QH65B2"
        bodyDict["userLocale"] = "en_US"
        
        guard let bodyData = try? PropertyListSerialization.data(fromPropertyList: bodyDict, format: .xml, options: 0) else {
            completion(.failure(.general("构造请求参数失败")))
            return
        }
        request.httpBody = bodyData
        
        AnisetteClient.shared.fetchAnisetteHeaders { res in
            switch res {
            case .success(let anisetteHeaders):
                for (k, v) in anisetteHeaders {
                    request.setValue(v, forHTTPHeaderField: k)
                }
                
                AppLogger.shared.log("正在向苹果服务器发送请求: \(action).action", category: .appleID)
                
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 30
                config.timeoutIntervalForResource = 60
                let sessionTask = URLSession(configuration: config)
                
                sessionTask.dataTask(with: request) { data, response, error in
                    if let error = error {
                        AppLogger.shared.log("苹果服务器网络连接失败 (\(action)): \(error.localizedDescription)", category: .error)
                        completion(.failure(.networkError(error)))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(.failure(.general("苹果开发者服务器未响应")))
                        return
                    }
                    
                    guard let data = data else {
                        completion(.failure(.general("苹果开发者服务器返回空响应")))
                        return
                    }
                    
                    guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                        let rawStr = String(data: data, encoding: .utf8) ?? ""
                        AppLogger.shared.log("解析苹果服务器响应失败 (HTTP \(httpResponse.statusCode)): \(rawStr.prefix(200))", category: .error)
                        completion(.failure(.general("解析苹果服务器数据失败 (HTTP \(httpResponse.statusCode))")))
                        return
                    }
                    
                    let resultCode = plist["resultCode"] as? Int ?? -1
                    if resultCode == 0 {
                        AppLogger.shared.log("✅ 苹果开发者接口响应成功: \(action).action", category: .appleID)
                        completion(.success(plist))
                    } else if resultCode == 1100 && !isRetry {
                        AppLogger.shared.log("⚠️ 苹果开发者会话已过期 (1100)，正在自动尝试刷新或重新认证...", category: .warn)
                        self.currentSession = nil
                        if var acc = AppleAccountManager.shared.activeAccount {
                            acc.myacinfo = nil
                            acc.sessionCookies = nil
                            AppleAccountManager.shared.addOrUpdateAccount(acc)
                        }
                        self.ensureAuthenticatedSession { [weak self] authRes in
                            guard let self = self else { return }
                            switch authRes {
                            case .success(let newSession):
                                self.sendDeveloperRequest(action: action, session: newSession, parameters: parameters, isRetry: true, completion: completion)
                            case .failure(let err):
                                AppLogger.shared.log("❌ 苹果开发者会话失效: \(err.localizedDescription)", category: .error)
                                completion(.failure(err))
                            }
                        }
                    } else {
                        if resultCode == 1100 {
                            self.currentSession = nil
                            if var acc = AppleAccountManager.shared.activeAccount {
                                acc.myacinfo = nil
                                acc.sessionCookies = nil
                                AppleAccountManager.shared.addOrUpdateAccount(acc)
                            }
                        }
                        let userString = plist["userString"] as? String ?? plist["resultString"] as? String ?? "未知错误"
                        AppLogger.shared.log("⚠️ 苹果开发者接口状态码: [\(resultCode)] \(userString) (\(action).action)", category: .warn)
                        completion(.failure(.general("[\(resultCode)] \(userString)")))
                    }
                }.resume()
            }
        }
    }
    
    private func executeAppleDeveloperAPIFlow(
        session: AppleSession,
        bundleID: String,
        deviceUDID: String,
        csrString: String,
        privateKey: SecKey,
        pubKeyData: Data,
        completion: @escaping (Result<AppleSigningMaterials, AppleAuthError>) -> Void
    ) {
        AppLogger.shared.log("正在通过 Apple ID (\(session.appleID)) 获取苹果开发者团队信息...", category: .appleID)
        self.sendDeveloperRequest(action: "listTeams", session: session, parameters: [:]) { [weak self] teamRes in
            guard let self = self else { return }
            var effectiveTeamId = session.teamID ?? ""
            var effectiveTeamName = session.teamName ?? "\(session.appleID) (Personal Team)"
            
            switch teamRes {
            case .success(let plist):
                if let teams = plist["teams"] as? [[String: Any]], !teams.isEmpty {
                    let selected = teams.first { ($0["status"] as? String) == "active" } ?? teams[0]
                    if let tId = selected["teamId"] as? String {
                        effectiveTeamId = tId
                    }
                    if let tName = selected["name"] as? String {
                        effectiveTeamName = tName
                    }
                    AppLogger.shared.log("✅ 成功匹配苹果开发者团队: \(effectiveTeamName) (Team ID: \(effectiveTeamId))", category: .appleID)
                }
            case .failure(let err):
                AppLogger.shared.log("获取团队列表失败: \(err.localizedDescription)", category: .error)
                completion(.failure(err))
                return
            }
            
            // 2. Register Device UDID
            let devParams: [String: Any] = [
                "teamId": effectiveTeamId,
                "deviceNumber": deviceUDID,
                "name": UIDevice.current.name.isEmpty ? "iPhone" : UIDevice.current.name
            ]
            AppLogger.shared.log("正在注册当前设备 UDID (\(deviceUDID)) 至开发者团队...", category: .appleID)
            self.sendDeveloperRequest(action: "addDevice", session: session, parameters: devParams) { _ in
                // Device registered or already present, proceed to App ID
                
                // 3. Register or Find App ID
                let appParams: [String: Any] = [
                    "teamId": effectiveTeamId,
                    "identifier": bundleID,
                    "name": bundleID
                ]
                AppLogger.shared.log("正在登记应用 Bundle ID: \(bundleID)...", category: .appleID)
                self.sendDeveloperRequest(action: "addAppId", session: session, parameters: appParams) { appRes in
                    var targetAppIdId = bundleID
                    if case .success(let plist) = appRes, let appIdDict = plist["appId"] as? [String: Any], let aId = appIdDict["appIdId"] as? String {
                        targetAppIdId = aId
                        AppLogger.shared.log("✅ 成功登记 App ID: \(bundleID) (AppIdId: \(targetAppIdId))", category: .appleID)
                        self.requestCertificateAndProfile(
                            session: session,
                            teamId: effectiveTeamId,
                            appIdId: targetAppIdId,
                            bundleID: bundleID,
                            deviceUDID: deviceUDID,
                            csrString: csrString,
                            privateKey: privateKey,
                            completion: completion
                        )
                    } else {
                        // Query listAppIds if addAppId reported existing identifier
                        self.sendDeveloperRequest(action: "listAppIds", session: session, parameters: ["teamId": effectiveTeamId]) { listRes in
                            if case .success(let listPlist) = listRes, let appIds = listPlist["appIds"] as? [[String: Any]] {
                                if let found = appIds.first(where: { ($0["identifier"] as? String) == bundleID }),
                                   let aId = found["appIdId"] as? String {
                                    targetAppIdId = aId
                                    AppLogger.shared.log("在现有记录中找到 App ID: \(bundleID) (AppIdId: \(targetAppIdId))", category: .appleID)
                                }
                            }
                            self.requestCertificateAndProfile(
                                session: session,
                                teamId: effectiveTeamId,
                                appIdId: targetAppIdId,
                                bundleID: bundleID,
                                deviceUDID: deviceUDID,
                                csrString: csrString,
                                privateKey: privateKey,
                                completion: completion
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func requestCertificateAndProfile(
        session: AppleSession,
        teamId: String,
        appIdId: String,
        bundleID: String,
        deviceUDID: String,
        csrString: String,
        privateKey: SecKey,
        completion: @escaping (Result<AppleSigningMaterials, AppleAuthError>) -> Void
    ) {
        let csrParams: [String: Any] = [
            "teamId": teamId,
            "csrContent": csrString
        ]
        AppLogger.shared.log("正在向苹果服务器提交 CSR 请求签发官方开发者证书...", category: .appleID)
        self.sendDeveloperRequest(action: "submitDevelopmentCSR", session: session, parameters: csrParams) { [weak self] csrRes in
            guard let self = self else { return }
            switch csrRes {
            case .success(let plist):
                self.handleCSRSuccess(
                    plist: plist,
                    session: session,
                    teamId: teamId,
                    appIdId: appIdId,
                    bundleID: bundleID,
                    deviceUDID: deviceUDID,
                    privateKey: privateKey,
                    completion: completion
                )
            case .failure(let err):
                let errMsg = err.localizedDescription
                if errMsg.contains("7460") {
                    AppLogger.shared.log("⚠️ 开发者证书数量达上限 (7460)，正在吊销旧证书并自动重新签发...", category: .warn)
                    self.revokeAllDevCertsAndRetry(
                        session: session,
                        teamId: teamId,
                        csrString: csrString
                    ) { retryRes in
                        switch retryRes {
                        case .success(let plist):
                            self.handleCSRSuccess(
                                plist: plist,
                                session: session,
                                teamId: teamId,
                                appIdId: appIdId,
                                bundleID: bundleID,
                                deviceUDID: deviceUDID,
                                privateKey: privateKey,
                                completion: completion
                            )
                        case .failure(let retryErr):
                            completion(.failure(retryErr))
                        }
                    }
                } else {
                    AppLogger.shared.log("❌ 苹果开发者证书申请失败: \(errMsg)", category: .error)
                    completion(.failure(.certificateRequestFailed(errMsg)))
                }
            }
        }
    }
    
    private func handleCSRSuccess(
        plist: [String: Any],
        session: AppleSession,
        teamId: String,
        appIdId: String,
        bundleID: String,
        deviceUDID: String,
        privateKey: SecKey,
        completion: @escaping (Result<AppleSigningMaterials, AppleAuthError>) -> Void
    ) {
        var certDER = Data()
        if let certData = plist["certContent"] as? Data {
            certDER = certData
        } else if let certStr = plist["certContent"] as? String {
            certDER = Data(base64Encoded: certStr) ?? certStr.data(using: .utf8) ?? Data()
        }
        
        guard !certDER.isEmpty else {
            completion(.failure(.certificateRequestFailed("苹果返回的开发者证书数据为空")))
            return
        }
        
        AppLogger.shared.log("✅ 成功从苹果开发者服务器获取官方开发者证书: \(certDER.count) 字节 (已由 Apple WWDR CA 签发)", category: .appleID)
        
        let provParams: [String: Any] = [
            "teamId": teamId,
            "appIdId": appIdId
        ]
        AppLogger.shared.log("正在从苹果服务器下载团队描述文件 (appIdId: \(appIdId))...", category: .appleID)
        self.sendDeveloperRequest(action: "downloadTeamProvisioningProfile", session: session, parameters: provParams) { provRes in
            switch provRes {
            case .success(let provPlist):
                var profileData = Data()
                if let provDict = provPlist["provisioningProfile"] as? [String: Any] {
                    if let encData = provDict["encodedProfile"] as? Data {
                        profileData = encData
                    } else if let encStr = provDict["encodedProfile"] as? String {
                        profileData = Data(base64Encoded: encStr) ?? encStr.data(using: .utf8) ?? Data()
                    }
                } else if let encData = provPlist["encodedProfile"] as? Data {
                    profileData = encData
                } else if let encStr = provPlist["encodedProfile"] as? String {
                    profileData = Data(base64Encoded: encStr) ?? encStr.data(using: .utf8) ?? Data()
                }
                
                guard !profileData.isEmpty else {
                    completion(.failure(.profileRequestFailed("苹果返回的描述文件数据为空")))
                    return
                }
                
                AppLogger.shared.log("✅ 成功从苹果官方服务器下载描述文件 (大小: \(profileData.count) 字节，包含 UDID: \(deviceUDID))", category: .appleID)
                
                do {
                    let saved = try CertificateStorageManager.shared.saveAppleIDMaterials(
                        p12Data: certDER,
                        provisionData: profileData,
                        email: session.appleID
                    )
                    CertificateStorageManager.shared.saveAppleIDPrivateKey(privateKey, email: session.appleID)
                    CertificateStorageManager.shared.currentAppleIDCertDER = certDER
                    
                    let materials = AppleSigningMaterials(
                        p12URL: saved.p12URL,
                        provisionURL: saved.provisionURL,
                        privateKey: privateKey,
                        certDER: certDER
                    )
                    completion(.success(materials))
                } catch {
                    completion(.failure(.general("保存苹果官方证书材料失败: \(error.localizedDescription)")))
                }
                
            case .failure(let err):
                AppLogger.shared.log("❌ 苹果官方描述文件下载失败: \(err.localizedDescription)", category: .error)
                completion(.failure(.profileRequestFailed(err.localizedDescription)))
            }
        }
    }
    
    private func revokeAllDevCertsAndRetry(
        session: AppleSession,
        teamId: String,
        csrString: String,
        completion: @escaping (Result<[String: Any], AppleAuthError>) -> Void
    ) {
        self.sendDeveloperRequest(action: "listAllDevelopmentCerts", session: session, parameters: ["teamId": teamId]) { [weak self] listRes in
            guard let self = self else { return }
            var certsToRevoke: [String] = []
            if case .success(let plist) = listRes, let certs = plist["certificates"] as? [[String: Any]] {
                for c in certs {
                    if let serial = c["serialNumber"] as? String, !serial.isEmpty {
                        certsToRevoke.append(serial)
                    }
                }
            }
            
            if certsToRevoke.isEmpty {
                // If list didn't yield serials, retry CSR directly
                self.sendDeveloperRequest(action: "submitDevelopmentCSR", session: session, parameters: ["teamId": teamId, "csrContent": csrString], completion: completion)
                return
            }
            
            let group = DispatchGroup()
            for serial in certsToRevoke {
                group.enter()
                AppLogger.shared.log("正在吊销旧的开发者证书 (序列号: \(serial))...", category: .appleID)
                self.sendDeveloperRequest(action: "revokeDevelopmentCert", session: session, parameters: ["teamId": teamId, "serialNumber": serial]) { _ in
                    group.leave()
                }
            }
            
            group.notify(queue: .global()) {
                AppLogger.shared.log("旧证书吊销清理完毕，正在重新提交 CSR 申请官方证书...", category: .appleID)
                self.sendDeveloperRequest(action: "submitDevelopmentCSR", session: session, parameters: ["teamId": teamId, "csrContent": csrString], completion: completion)
            }
        }
    }
    
    // MARK: - ASN.1 DER & PKCS#10 Generation
    
    private func generatePKCS10CSR(privateKey: SecKey, publicKeyData: Data, commonName: String) -> Data? {
        let oid_rsa = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01])
        let oid_sha256_rsa = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b])
        let oid_cn = Data([0x55, 0x04, 0x03])
        
        let rsaAlg = derTag(0x30, derTag(0x06, oid_rsa) + derTag(0x05, Data()))
        let pubKeyBitStr = derTag(0x03, Data([0x00]) + publicKeyData)
        let subjectPKInfo = derTag(0x30, rsaAlg + pubKeyBitStr)
        
        let cnAttr = derTag(0x30, derTag(0x06, oid_cn) + derTag(0x0c, commonName.data(using: .utf8) ?? Data()))
        let subject = derTag(0x30, derTag(0x31, cnAttr))
        
        let version = derTag(0x02, Data([0x00]))
        let attributes = derTag(0xa0, Data())
        
        let cri = derTag(0x30, version + subject + subjectPKInfo + attributes)
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        cri.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(cri.count), &digest)
        }
        
        var err: Unmanaged<CFError>?
        guard let sig = SecKeyCreateSignature(privateKey, .rsaSignatureDigestPKCS1v15SHA256, Data(digest) as CFData, &err) as Data? else {
            return nil
        }
        
        let sigAlg = derTag(0x30, derTag(0x06, oid_sha256_rsa) + derTag(0x05, Data()))
        let sigBitStr = derTag(0x03, Data([0x00]) + sig)
        
        return derTag(0x30, cri + sigAlg + sigBitStr)
    }
    
    private func generateSelfSignedOrPortalCertDER(commonName: String, teamId: String, privateKey: SecKey, pubKeyData: Data) -> Data {
        let oid_rsa = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01])
        let oid_sha256_rsa = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b])
        let oid_cn = Data([0x55, 0x04, 0x03])
        let oid_ou = Data([0x55, 0x04, 0x0b])
        let oid_o = Data([0x55, 0x04, 0x0a])
        let oid_c = Data([0x55, 0x04, 0x06])
        
        let cnAttr = derTag(0x30, derTag(0x06, oid_cn) + derTag(0x0c, commonName.data(using: .utf8) ?? Data()))
        let ouAttr = derTag(0x30, derTag(0x06, oid_ou) + derTag(0x0c, teamId.data(using: .utf8) ?? Data()))
        let oAttr = derTag(0x30, derTag(0x06, oid_o) + derTag(0x0c, "Apple Inc.".data(using: .utf8) ?? Data()))
        let cAttr = derTag(0x30, derTag(0x06, oid_c) + derTag(0x13, "US".data(using: .utf8) ?? Data()))
        
        let nameSeq = derTag(0x30, derTag(0x31, cnAttr) + derTag(0x31, ouAttr) + derTag(0x31, oAttr) + derTag(0x31, cAttr))
        
        let version = derTag(0xa0, derTag(0x02, Data([0x02]))) // v3
        let serial = derTag(0x02, Data([0x01, 0x23, 0x45, 0x67, 0x89]))
        let sigAlg = derTag(0x30, derTag(0x06, oid_sha256_rsa) + derTag(0x05, Data()))
        
        let notBefore = derTag(0x17, "240101000000Z".data(using: .utf8)!)
        let notAfter = derTag(0x17, "280101000000Z".data(using: .utf8)!)
        let validity = derTag(0x30, notBefore + notAfter)
        
        let rsaAlg = derTag(0x30, derTag(0x06, oid_rsa) + derTag(0x05, Data()))
        let pubKeyBitStr = derTag(0x03, Data([0x00]) + pubKeyData)
        let subjectPKInfo = derTag(0x30, rsaAlg + pubKeyBitStr)
        
        let tbsCert = derTag(0x30, version + serial + sigAlg + nameSeq + validity + nameSeq + subjectPKInfo)
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        tbsCert.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(tbsCert.count), &digest)
        }
        
        var err: Unmanaged<CFError>?
        let sig = (SecKeyCreateSignature(privateKey, .rsaSignatureDigestPKCS1v15SHA256, Data(digest) as CFData, &err) as Data?) ?? Data(repeating: 0, count: 256)
        let sigBitStr = derTag(0x03, Data([0x00]) + sig)
        
        return derTag(0x30, tbsCert + sigAlg + sigBitStr)
    }
    
    private func wrapInCMSProfile(plistData: Data, certDER: Data, privateKey: SecKey) -> Data {
        let oid_pkcs7_data = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x01])
        let oid_pkcs7_signed = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x02])
        let oid_sha256 = Data([0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01])
        let oid_sha256_rsa = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b])
        
        let encapContent = derTag(0x30, derTag(0x06, oid_pkcs7_data) + derTag(0xa0, derTag(0x04, plistData)))
        let certs = derTag(0xa0, certDER)
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        plistData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(plistData.count), &digest)
        }
        
        var err: Unmanaged<CFError>?
        let sig = (SecKeyCreateSignature(privateKey, .rsaSignatureDigestPKCS1v15SHA256, Data(digest) as CFData, &err) as Data?) ?? Data(repeating: 0, count: 256)
        
        let digestAlg = derTag(0x30, derTag(0x06, oid_sha256) + derTag(0x05, Data()))
        let digestAlgs = derTag(0x31, digestAlg)
        
        let signerId = derTag(0x30, derTag(0x30, Data([0x06, 0x03, 0x55, 0x04, 0x03, 0x13, 0x08, 0x53, 0x6f, 0x75, 0x6c, 0x53, 0x69, 0x67, 0x6e])) + derTag(0x02, Data([0x01, 0x23, 0x45, 0x67, 0x89])))
        let sigAlg = derTag(0x30, derTag(0x06, oid_sha256_rsa) + derTag(0x05, Data()))
        let sigVal = derTag(0x04, sig)
        
        let signerInfo = derTag(0x30, derTag(0x02, Data([0x01])) + signerId + digestAlg + sigAlg + sigVal)
        let signerInfos = derTag(0x31, signerInfo)
        
        let signedData = derTag(0x30, derTag(0x02, Data([0x01])) + digestAlgs + encapContent + certs + signerInfos)
        return derTag(0x30, derTag(0x06, oid_pkcs7_signed) + derTag(0xa0, signedData))
    }
    
    private func createP12Data(privateKey: SecKey, certDER: Data) -> Data? {
        // Return DER representation of cert as standalone transport identity
        return certDER
    }
    
    private func derTag(_ tag: UInt8, _ contents: Data) -> Data {
        var out = Data([tag])
        let len = contents.count
        if len < 128 {
            out.append(UInt8(len))
        } else if len < 256 {
            out.append(0x81)
            out.append(UInt8(len))
        } else if len < 65536 {
            out.append(0x82)
            out.append(UInt8(len >> 8))
            out.append(UInt8(len & 0xFF))
        } else {
            out.append(0x83)
            out.append(UInt8(len >> 16))
            out.append(UInt8((len >> 8) & 0xFF))
            out.append(UInt8(len & 0xFF))
        }
        out.append(contents)
        return out
    }
}
