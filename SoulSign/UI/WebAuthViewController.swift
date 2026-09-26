import UIKit
import WebKit

class WebAuthViewController: UIViewController, WKNavigationDelegate {
    var initialEmail: String?

    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let tipBanner = UILabel()
    private var checkTimer: Timer?
    private var isFinishing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple 网页快捷登录"
        view.backgroundColor = .systemBackground

        setupNavigation()
        setupUI()
        loadLoginPage()
        startSessionPolling()

        AppLogger.shared.log("打开 Apple 官方网页登录页面", category: .auth)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        let doneButton = UIBarButtonItem(
            title: "完成登录",
            style: .done,
            target: self,
            action: #selector(manualDoneTapped)
        )
        navigationItem.rightBarButtonItem = doneButton
    }

    private func setupUI() {
        // Tip Banner
        tipBanner.text = "💡 在下方完成 Apple ID 登录后会自动识别，亦可点击右上角「完成登录」"
        tipBanner.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        tipBanner.textColor = SoulSignTheme.primaryDark
        tipBanner.backgroundColor = SoulSignTheme.primary.withAlphaComponent(0.12)
        tipBanner.textAlignment = .center
        tipBanner.numberOfLines = 0
        tipBanner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipBanner)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)

        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            tipBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tipBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tipBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tipBanner.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),

            progressView.topAnchor.constraint(equalTo: tipBanner.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }

    private func loadLoginPage() {
        if let url = URL(string: "https://developer.apple.com/account/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    private func startSessionPolling() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkCurrentSession(auto: true)
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1.0
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkCurrentSession(auto: true)
    }

    @objc private func manualDoneTapped() {
        checkCurrentSession(auto: false)
    }

    private func checkCurrentSession(auto: Bool) {
        guard !isFinishing else { return }

        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self, !self.isFinishing else { return }

            var cookieDict: [String: String] = [:]
            var hasAuthCookie = false

            for cookie in cookies {
                cookieDict[cookie.name] = cookie.value
                if cookie.name == "myacinfo" || cookie.name == "itctx" || cookie.name == "dqsid" {
                    if !cookie.value.isEmpty {
                        hasAuthCookie = true
                    }
                }
            }

            guard hasAuthCookie else {
                if !auto {
                    let alert = UIAlertController(
                        title: "提示",
                        message: "尚未检测到 Apple 登录凭据，请先在页面中输入账号密码完成登录。",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
                return
            }

            // Session cookie found!
            self.resolveAndFinish(cookies: cookieDict)
        }
    }

    private func resolveAndFinish(cookies: [String: String]) {
        self.isFinishing = true
        self.checkTimer?.invalidate()
        self.checkTimer = nil

        AppLogger.shared.log("检测到 Apple 网页登录凭据，正在获取真实 Apple ID 邮箱...", category: .auth)

        // 1. Check if user already entered email in previous screen
        if let initial = initialEmail?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
           initial.contains("@") && !initial.contains("apple_user_") {
            self.saveSessionAndDismiss(email: initial, cookies: cookies)
            return
        }

        // 2. Try fetching userInfo from Apple Developer API using the cookies
        fetchAppleUserInfo(cookies: cookies) { [weak self] detectedEmail in
            guard let self = self else { return }

            if let email = detectedEmail, email.contains("@") {
                AppLogger.shared.log("通过苹果接口成功识别账号: \(email)", category: .auth)
                self.saveSessionAndDismiss(email: email, cookies: cookies)
            } else {
                // 3. Fallback: Try reading email from DOM via JavaScript
                let js = "document.querySelector('.nav-user-name, [data-user-email], .account-email, #account_name_text, .user-name')?.innerText || ''"
                self.webView.evaluateJavaScript(js) { [weak self] result, _ in
                    guard let self = self else { return }
                    if let text = result as? String, text.contains("@") {
                        let cleaned = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        AppLogger.shared.log("通过网页 DOM 识别账号: \(cleaned)", category: .auth)
                        self.saveSessionAndDismiss(email: cleaned, cookies: cookies)
                    } else {
                        // Prompt user to enter their Apple ID email once
                        self.promptManualEmailInput(cookies: cookies)
                    }
                }
            }
        }
    }

    private func fetchAppleUserInfo(cookies: [String: String], completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://developer.apple.com/services-account/QH65B2/account/getUserInfo.action") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8.0
        let cookieHeader = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("Xcode (com.apple.dt.Xcode/15.4)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let user = json["user"] as? [String: Any],
                   let email = user["emailAddress"] as? String, !email.isEmpty {
                    DispatchQueue.main.async { completion(email) }
                    return
                }
                if let email = json["emailAddress"] as? String, !email.isEmpty {
                    DispatchQueue.main.async { completion(email) }
                    return
                }
            }
            DispatchQueue.main.async { completion(nil) }
        }.resume()
    }

    private func promptManualEmailInput(cookies: [String: String]) {
        let alert = UIAlertController(
            title: "登录成功",
            message: "已获取 Apple 登录凭据，请输入您登录的 Apple ID 邮箱以绑定：",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "您的 Apple ID 邮箱"
            tf.keyboardType = .emailAddress
            tf.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "绑定账号", style: .default) { [weak self] _ in
            let email = alert.textFields?.first?.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            let finalEmail = email.isEmpty ? "apple_account_\(Int(Date().timeIntervalSince1970) % 10000)@icloud.com" : email
            self?.saveSessionAndDismiss(email: finalEmail, cookies: cookies)
        })
        present(alert, animated: true)
    }

    private func saveSessionAndDismiss(email: String, cookies: [String: String]) {
        let session = DeveloperSession(
            appleID: email,
            authToken: "",
            cookies: cookies,
            expirationDate: Date().addingTimeInterval(86400 * 7)
        )

        DeveloperPortalAPI.shared.listTeams(session: session) { teamResult in
            var teamID: String? = nil
            var teamName: String? = nil
            if case .success(let teams) = teamResult, let first = teams.first {
                teamID = first.teamID
                teamName = first.name
            }

            AccountManager.shared.addOrUpdateAccount(
                email: email,
                session: session,
                teamID: teamID,
                teamName: teamName
            )
            AppLogger.shared.log("已成功绑定并登记 Apple ID: \(email) (团队: \(teamName ?? "个人"))", category: .auth)

            DispatchQueue.main.async { [weak self] in
                self?.dismiss(animated: true)
            }
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    deinit {
        checkTimer?.invalidate()
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}
