import UIKit
import WebKit

/// Apple Official Web Authorization View Controller
/// Loads Apple Developer Account portal in WKWebView to seamlessly support
/// Two-Factor Authentication (2FA), SMS verification, Passkeys, and Touch/Face ID.
/// Upon successful login, extracts `myacinfo` & session cookies for developerservices2.apple.com.
public class AppleWebLoginViewController: UIViewController, WKNavigationDelegate {
    
    public var prefilledEmail: String?
    public var onLoginSuccess: ((AppleAccount) -> Void)?
    
    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let tipBanner = UIView()
    private let tipLabel = UILabel()
    
    private var observation: NSKeyValueObservation?
    private var isCompleted = false
    private var isCleaningCookies = true
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupNavBar()
        setupUI()
        cleanOldCookiesAndLoad()
    }
    
    private func setupNavBar() {
        title = L("Apple 开发者官方授权", "Apple Official Sign In")
        navigationController?.navigationBar.prefersLargeTitles = false
        
        let closeItem = UIBarButtonItem(
            title: L("关闭", "Close"),
            style: .plain,
            target: self,
            action: #selector(closeAction)
        )
        navigationItem.leftBarButtonItem = closeItem
        
        let refreshItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshAction)
        )
        
        let doneItem = UIBarButtonItem(
            title: L("完成登录", "Done"),
            style: .done,
            target: self,
            action: #selector(manualConfirmAction)
        )
        doneItem.tintColor = UniSignTheme.primaryColor
        
        navigationItem.rightBarButtonItems = [doneItem, refreshItem]
    }
    
    private func setupUI() {
        // Tip banner
        tipBanner.translatesAutoresizingMaskIntoConstraints = false
        tipBanner.backgroundColor = UniSignTheme.primaryColor.withAlphaComponent(0.1)
        tipBanner.layer.cornerRadius = 8
        view.addSubview(tipBanner)
        
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        tipLabel.font = .systemFont(ofSize: 12, weight: .medium)
        tipLabel.textColor = UniSignTheme.primaryColor
        tipLabel.numberOfLines = 0
        tipLabel.text = L(
            "💡 请在下方页面中登录 Apple ID 并完成二次验证码 (2FA)。成功进入开发者后台后点击右上角「完成登录」。",
            "💡 Sign in with your Apple ID & complete 2FA. Once in the dashboard, tap 'Done' at top right."
        )
        tipBanner.addSubview(tipLabel)
        
        // Progress view
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = UniSignTheme.primaryColor
        view.addSubview(progressView)
        
        // Web view
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            tipBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            tipBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            tipBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            
            tipLabel.topAnchor.constraint(equalTo: tipBanner.topAnchor, constant: 8),
            tipLabel.bottomAnchor.constraint(equalTo: tipBanner.bottomAnchor, constant: -8),
            tipLabel.leadingAnchor.constraint(equalTo: tipBanner.leadingAnchor, constant: 10),
            tipLabel.trailingAnchor.constraint(equalTo: tipBanner.trailingAnchor, constant: -10),
            
            progressView.topAnchor.constraint(equalTo: tipBanner.bottomAnchor, constant: 6),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            guard let self = self, let progress = change.newValue else { return }
            self.progressView.progress = Float(progress)
            self.progressView.isHidden = (progress >= 1.0)
        }
    }
    
    private func cleanOldCookiesAndLoad() {
        isCleaningCookies = true
        AppLogger.shared.log("正在重置旧的 Apple 网页会话凭证，准备全新授权...", category: .appleID)
        
        let store = WKWebsiteDataStore.default().httpCookieStore
        store.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            let group = DispatchGroup()
            for c in cookies {
                if c.domain.contains("apple.com") || c.domain.contains("icloud.com") {
                    group.enter()
                    store.delete(c) {
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                self.isCleaningCookies = false
                self.loadLoginPage()
            }
        }
    }
    
    private func loadLoginPage() {
        guard let url = URL(string: "https://developer.apple.com/account/") else { return }
        AppLogger.shared.log("正在调起 Apple 官方安全登录页面...", category: .appleID)
        let req = URLRequest(url: url)
        webView.load(req)
    }
    
    @objc private func closeAction() {
        dismiss(animated: true)
    }
    
    @objc private func refreshAction() {
        webView.reload()
    }
    
    @objc private func manualConfirmAction() {
        checkCookiesForAuth(userInitiated: true)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isCleaningCookies else { return }
        
        let urlString = webView.url?.absoluteString.lowercased() ?? ""
        
        // If still in the login flow (idmsa.apple.com, auth, signin, etc.), do NOT auto-finish!
        // The user must be allowed to enter their password, receive SMS/push, and enter the 2FA code!
        if urlString.contains("idmsa.apple.com") ||
           urlString.contains("/auth/") ||
           urlString.contains("/signin") ||
           urlString.contains("/login") {
            AppLogger.shared.log("正在等待用户输入 Apple ID、密码及二次验证码...", category: .appleID)
            return
        }
        
        // If arrived at developer account dashboard, auto-check cookies
        if urlString.contains("developer.apple.com/account") ||
           urlString.contains("developer.apple.com/services-account") {
            checkCookiesForAuth(userInitiated: false)
        }
    }
    
    private func checkCookiesForAuth(userInitiated: Bool) {
        guard !isCompleted else { return }
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self, !self.isCompleted else { return }
            
            var cookieMap: [String: String] = [:]
            var foundMyacinfo: String?
            var foundDSID: String?
            
            for c in cookies {
                if c.domain.contains("apple.com") {
                    cookieMap[c.name] = c.value
                    if c.name == "myacinfo" && !c.value.isEmpty {
                        foundMyacinfo = c.value
                    }
                    if c.name == "dsid" && !c.value.isEmpty {
                        foundDSID = c.value
                    }
                }
            }
            
            // Check if we captured valid developer session token
            if let myacinfo = foundMyacinfo, myacinfo.count > 10 {
                self.isCompleted = true
                self.extractUserAndFinish(myacinfo: myacinfo, dsid: foundDSID ?? "", cookies: cookieMap)
            } else if userInitiated {
                let alert = UIAlertController(
                    title: L("尚未检测到登录凭证", "Session Not Detected"),
                    message: L("请先在下方页面中输入 Apple ID、密码及 6 位验证码，登录成功进入开发者后台后再点击「完成登录」。", "Please complete your Apple ID & 2FA login first, then tap Done."),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: L("好的", "OK"), style: .default))
                self.present(alert, animated: true)
            }
        }
    }
    
    private func extractUserAndFinish(myacinfo: String, dsid: String, cookies: [String: String]) {
        // Try to read logged-in user email from page DOM
        let js = """
        (function() {
            var el = document.querySelector('.nav-user-name') ||
                     document.querySelector('.account-name') ||
                     document.querySelector('span[data-email]') ||
                     document.querySelector('.user-email') ||
                     document.querySelector('button[id*="account"]');
            return el ? el.innerText.trim() : '';
        })();
        """
        
        webView.evaluateJavaScript(js) { [weak self] res, _ in
            guard let self = self else { return }
            var detectedEmail = (res as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !detectedEmail.contains("@") {
                detectedEmail = self.prefilledEmail ?? ""
            }
            
            if detectedEmail.isEmpty {
                self.promptForEmail(myacinfo: myacinfo, dsid: dsid, cookies: cookies)
            } else {
                self.finalizeLogin(email: detectedEmail, myacinfo: myacinfo, dsid: dsid, cookies: cookies)
            }
        }
    }
    
    private func promptForEmail(myacinfo: String, dsid: String, cookies: [String: String]) {
        let alert = UIAlertController(
            title: L("已完成 Apple 网页授权", "Apple Auth Complete"),
            message: L("请输入刚刚登录的 Apple ID 邮箱，以完成账号登记：", "Please confirm your Apple ID email:"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "example@icloud.com"
            tf.keyboardType = .emailAddress
            tf.autocapitalizationType = .none
            if let pre = self.prefilledEmail, !pre.isEmpty {
                tf.text = pre
            }
        }
        alert.addAction(UIAlertAction(title: L("确定", "OK"), style: .default, handler: { [weak self, weak alert] _ in
            let email = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "AppleUser"
            self?.finalizeLogin(email: email, myacinfo: myacinfo, dsid: dsid, cookies: cookies)
        }))
        present(alert, animated: true)
    }
    
    private func finalizeLogin(email: String, myacinfo: String, dsid: String, cookies: [String: String]) {
        let cleanTeamId = "TEAM" + String(abs(email.hashValue) % 1000000000)
        
        let session = AppleDeveloperService.AppleSession(
            appleID: email,
            dsid: dsid,
            authToken: myacinfo,
            teamID: cleanTeamId,
            teamName: "\(email) (Personal Team)",
            cookies: cookies
        )
        AppleDeveloperService.shared.currentSession = session
        
        let account = AppleAccount(
            email: email,
            password: "",
            teamID: session.teamID,
            teamName: session.teamName,
            isActive: true,
            myacinfo: myacinfo,
            sessionCookies: cookies
        )
        AppleAccountManager.shared.addOrUpdateAccount(account)
        AppleAccountManager.shared.setActiveAccount(id: account.id)
        
        AppLogger.shared.log("✅ 成功通过 Apple 官方网页完成授权: \(email), myacinfo 凭据与 2FA 会话 Cookie 已就绪", category: .appleID)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        self.onLoginSuccess?(account)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dismiss(animated: true)
        }
    }
}
