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
    private var observation: NSKeyValueObservation?
    private var isCompleted = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupNavBar()
        setupWebView()
        loadLoginPage()
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
        navigationItem.rightBarButtonItem = refreshItem
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = UniSignTheme.primaryColor
        view.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkCookiesForAuth()
    }
    
    private func checkCookiesForAuth() {
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
            if let myacinfo = foundMyacinfo, !myacinfo.isEmpty {
                self.isCompleted = true
                self.extractUserAndFinish(myacinfo: myacinfo, dsid: foundDSID ?? "", cookies: cookieMap)
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
        
        AppLogger.shared.log("✅ 成功通过 Apple 官方网页完成授权: \(email), myacinfo 凭证已就绪", category: .appleID)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        self.onLoginSuccess?(account)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dismiss(animated: true)
        }
    }
    
    deinit {
        observation?.invalidate()
    }
}
