import UIKit
import WebKit

public class WebAuthViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .bar)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple 网页登录"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(progressView)
        progressView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        // Load Apple ID developer login page
        if let url = URL(string: "https://appleid.apple.com/sign-in") {
            webView.load(URLRequest(url: url))
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = (webView.estimatedProgress >= 1.0)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Extract cookies
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            var cookieDict: [String: String] = [:]
            for c in cookies {
                cookieDict[c.name] = c.value
            }

            if let myacinfo = cookieDict["myacinfo"], !myacinfo.isEmpty {
                // Successful session captured
                let session = DeveloperSession(
                    appleID: "web-user@appleid.com",
                    authToken: myacinfo,
                    cookies: cookieDict
                )
                AccountManager.shared.addOrUpdateAccount(
                    email: "web-user@appleid.com",
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
