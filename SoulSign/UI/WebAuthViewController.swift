import UIKit
import WebKit

class WebAuthViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .bar)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple 网页快捷登录"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        setupWebView()
        loadLoginPage()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        progressView.translatesAutoresizingMaskIntoConstraints = false
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

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }

    private func loadLoginPage() {
        if let url = URL(string: "https://developer.apple.com/account/") {
            let request = URLRequest(url: url)
            webView.load(request)
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
        guard let currentURL = webView.url?.absoluteString else { return }

        if currentURL.contains("developer.apple.com/account") && !currentURL.contains("auth/login") {
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                var cookieDict: [String: String] = [:]
                var accountEmail = "developer@apple.com"

                for cookie in cookies {
                    cookieDict[cookie.name] = cookie.value
                    if cookie.name == "myacinfo" || cookie.name.contains("user") {
                        if !cookie.value.isEmpty {
                            accountEmail = "apple_user_\(abs(cookie.value.hashValue % 100000))@icloud.com"
                        }
                    }
                }

                let session = DeveloperSession(
                    appleID: accountEmail,
                    authToken: "",
                    cookies: cookieDict,
                    expirationDate: Date().addingTimeInterval(86400 * 7)
                )

                AccountManager.shared.addOrUpdateAccount(
                    email: accountEmail,
                    session: session
                )
                self?.dismiss(animated: true)
            }
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}
