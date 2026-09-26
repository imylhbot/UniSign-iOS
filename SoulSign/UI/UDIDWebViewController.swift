import UIKit
import WebKit

class UDIDWebViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let tipLabel = UILabel()
    private var hasCaptured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "获取真实设备 UDID"
        view.backgroundColor = .systemBackground

        setupNavigation()
        setupUI()
        loadUDIDPage()

        AppLogger.shared.log("打开在线 UDID 获取网页: \(DeviceUDIDHelper.customUDIDURL)", category: .server)
    }

    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )

        let pasteBtn = UIBarButtonItem(
            title: "粘贴结果网址",
            style: .plain,
            target: self,
            action: #selector(pasteResultURLTapped)
        )
        navigationItem.rightBarButtonItem = pasteBtn
    }

    private func setupUI() {
        tipLabel.text = "💡 点击网页中的获取按钮下载描述文件，在系统「设置」安装后将自动返回抓取结果"
        tipLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        tipLabel.textColor = SoulSignTheme.primaryDark
        tipLabel.backgroundColor = SoulSignTheme.primary.withAlphaComponent(0.12)
        tipLabel.textAlignment = .center
        tipLabel.numberOfLines = 0
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipLabel)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)

        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            tipLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tipLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tipLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tipLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),

            progressView.topAnchor.constraint(equalTo: tipLabel.bottomAnchor),
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

    private func loadUDIDPage() {
        if let url = URL(string: DeviceUDIDHelper.customUDIDURL) {
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

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if checkAndExtractUDID(from: url) {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            _ = checkAndExtractUDID(from: url)
        }
    }

    private func checkAndExtractUDID(from url: URL) -> Bool {
        guard !hasCaptured else { return true }

        let urlString = url.absoluteString
        if urlString.contains("udid=") || urlString.contains("/result") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if let udidItem = components.queryItems?.first(where: { $0.name.lowercased() == "udid" }),
                   let udid = udidItem.value, !udid.isEmpty {
                    let product = components.queryItems?.first(where: { $0.name.lowercased() == "product" })?.value ?? "iOS Device"
                    let version = components.queryItems?.first(where: { $0.name.lowercased() == "version" })?.value ?? ""
                    let serial = components.queryItems?.first(where: { $0.name.lowercased() == "serial" })?.value ?? ""

                    captureSuccess(udid: udid, product: product, version: version, serial: serial)
                    return true
                }
            }
        }
        return false
    }

    private func captureSuccess(udid: String, product: String, version: String, serial: String) {
        guard !hasCaptured else { return }
        hasCaptured = true

        DeviceUDIDHelper.setDeviceInfo(udid: udid, product: product)
        AppLogger.shared.log("成功抓取真实物理 UDID: \(udid) (设备: \(product), 固件: \(version), 序号: \(serial))", category: .server)

        let alert = UIAlertController(
            title: "🎉 真实 UDID 抓取成功",
            message: "设备型号: \(product)\nUDID: \(udid)\n已自动绑定至 SoulSign 签名凭据！",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定并返回", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true)
        }))
        present(alert, animated: true)
    }

    @objc private func pasteResultURLTapped() {
        let alert = UIAlertController(
            title: "粘贴返回结果网址",
            message: "若在 Safari 中打开了返回网址 (如 https://udid.192688.xyz/result?udid=...)，请在此粘贴：",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "https://udid.192688.xyz/result?udid=..."
            if let str = UIPasteboard.general.string, str.contains("udid=") {
                tf.text = str.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
        }
        alert.addAction(UIAlertAction(title: "解析并绑定", style: .default, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
               let url = URL(string: text) {
                if !(self?.checkAndExtractUDID(from: url) ?? false) {
                    // Try parsing manually if it is direct UDID
                    if text.count >= 25 && text.count <= 40 {
                        self?.captureSuccess(udid: text, product: "Manual Input", version: "", serial: "")
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}
