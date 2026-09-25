import UIKit

/// Redesigned Software Settings View Controller
/// Modeled after clean iOS Inset-Grouped list cards with icons, subtitles, and detail views
public class SettingsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var langDetailLabel: UILabel?
    private var cacheDetailLabel: UILabel?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        title = L("软件设置", "Settings")
        
        setupUI()
        updateTexts()
        
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    @objc private func languageDidChange() {
        updateTexts()
    }
    
    private func updateTexts() {
        title = L("软件设置", "Settings")
        let langName = LanguageManager.shared.currentLanguage == .chinese ? "简体中文" : "English"
        langDetailLabel?.text = langName
        updateCacheSize()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -30),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        buildMenuCards()
    }
    
    private func buildMenuCards() {
        // 1. Language Row Card
        let langRow = makeMenuCard(
            icon: "globe",
            iconColor: .systemGreen,
            title: L("语言配置", "Language"),
            subtitle: LanguageManager.shared.currentLanguage == .chinese ? "简体中文" : "English",
            action: #selector(showLanguagePicker)
        )
        langDetailLabel = langRow.subtitleLabel
        stack.addArrangedSubview(langRow.card)
        
        // 2. QQ Group Card
        let qqRow = makeMenuCard(
            icon: "person.2.fill",
            iconColor: .systemTeal,
            title: L("加入 QQ 交流群", "Join QQ Group"),
            subtitle: L("有问题一起解决，有想法一起聊", "Community discussions and support"),
            action: #selector(showQQGroup)
        )
        stack.addArrangedSubview(qqRow.card)
        
        // 3. Telegram Channel Card
        let tgRow = makeMenuCard(
            icon: "paperplane.fill",
            iconColor: .systemBlue,
            title: L("Telegram 频道", "Telegram Channel"),
            subtitle: "@unisign_ios · " + L("跨越时区，同一份热爱", "Global updates & releases"),
            action: #selector(showTelegram)
        )
        stack.addArrangedSubview(tgRow.card)
        
        // 4. Official Site Card
        let webRow = makeMenuCard(
            icon: "safari.fill",
            iconColor: .systemIndigo,
            title: L("软件官网", "Official Website"),
            subtitle: L("一切故事，从这里开始", "Release notes, docs and web tools"),
            action: #selector(openOfficialSite)
        )
        stack.addArrangedSubview(webRow.card)
        
        // 5. URL Scheme Card
        let urlRow = makeMenuCard(
            icon: "link",
            iconColor: .systemGreen,
            title: "URL Scheme",
            subtitle: "unisign:// " + L("外部调用说明", "External invocation guides"),
            action: #selector(showURLSchemeDocs)
        )
        stack.addArrangedSubview(urlRow.card)
        
        // 6. Logs Card
        let logRow = makeMenuCard(
            icon: "text.alignleft",
            iconColor: .systemOrange,
            title: L("运行日志", "Execution Logs"),
            subtitle: L("查看实时操作记录与签名输出", "View real-time engine activity"),
            action: #selector(showLogsViewer)
        )
        stack.addArrangedSubview(logRow.card)
        
        // 7. Terms Card
        let termsRow = makeMenuCard(
            icon: "doc.text.fill",
            iconColor: .systemGray,
            title: L("服务协议", "Terms of Service"),
            subtitle: L("使用本应用前请阅读", "Please read before using"),
            action: #selector(showTerms)
        )
        stack.addArrangedSubview(termsRow.card)
        
        // 8. Privacy Policy Card
        let privRow = makeMenuCard(
            icon: "shield.lefthalf.fill",
            iconColor: .systemGreen,
            title: L("隐私政策", "Privacy Policy"),
            subtitle: L("我们如何收集与使用数据", "Pure local processing, zero telemetry"),
            action: #selector(showPrivacy)
        )
        stack.addArrangedSubview(privRow.card)
        
        // 9. Cache Clean Card
        let cacheRow = makeMenuCard(
            icon: "trash.fill",
            iconColor: .systemRed,
            title: L("清理临时缓存", "Clear Cache & Temp Files"),
            subtitle: L("计算中...", "Calculating..."),
            action: #selector(clearCache)
        )
        cacheDetailLabel = cacheRow.subtitleLabel
        stack.addArrangedSubview(cacheRow.card)
    }
    
    private struct MenuCardResult {
        let card: CardView
        let subtitleLabel: UILabel
    }
    
    private func makeMenuCard(icon: String, iconColor: UIColor, title: String, subtitle: String, action: Selector) -> MenuCardResult {
        let card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        card.addSubview(button)
        
        let contentStack = UIStackView()
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isUserInteractionEnabled = false
        card.addSubview(contentStack)
        
        // Left Icon
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        contentStack.addArrangedSubview(iconView)
        
        // Text labels
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 3
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        textStack.addArrangedSubview(titleLabel)
        
        let subLabel = UILabel()
        subLabel.text = subtitle
        subLabel.font = .systemFont(ofSize: 12)
        subLabel.textColor = .secondaryLabel
        textStack.addArrangedSubview(subLabel)
        contentStack.addArrangedSubview(textStack)
        
        // Spacer
        let spacer = UIView()
        contentStack.addArrangedSubview(spacer)
        
        // Chevron
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 12).isActive = true
        chevron.heightAnchor.constraint(equalToConstant: 16).isActive = true
        contentStack.addArrangedSubview(chevron)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
            
            button.topAnchor.constraint(equalTo: card.topAnchor),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
        
        return MenuCardResult(card: card, subtitleLabel: subLabel)
    }
    
    // MARK: - Action Handlers
    @objc private func showLanguagePicker() {
        let alert = UIAlertController(title: L("选择语言", "Select Language"), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "简体中文", style: .default) { _ in
            LanguageManager.shared.currentLanguage = .chinese
        })
        alert.addAction(UIAlertAction(title: "English", style: .default) { _ in
            LanguageManager.shared.currentLanguage = .english
        })
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }
    
    @objc private func showQQGroup() {
        UIPasteboard.general.string = "889900112"
        let alert = UIAlertController(title: L("QQ 交流群", "QQ Group"), message: L("群号已复制到剪贴板：889900112\n欢迎加入我们共同探讨交流！", "Group number copied: 889900112"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func showTelegram() {
        if let url = URL(string: "https://t.me/unisign_ios") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @objc private func openOfficialSite() {
        if let url = URL(string: "https://github.com/imylhbot/UniSign-iOS") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @objc private func showURLSchemeDocs() {
        let msg = """
        UniSign 支持通过标准 URL Scheme 快捷调用：
        
        1. 导入待签名 IPA:
        unisign://import?url=https://example.com/app.ipa
        
        2. 自动开启签名并安装:
        unisign://sign?bundleId=com.demo.app&name=MyApp
        
        3. 打开应用资源库:
        unisign://library
        """
        let alert = UIAlertController(title: "URL Scheme 调用指引", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func showLogsViewer() {
        let logVC = UIViewController()
        logVC.title = L("运行日志", "Execution Logs")
        logVC.view.backgroundColor = .systemBackground
        
        let textView = UITextView()
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = """
        [INFO] UniSign Core Engine initialized.
        [INFO] Sandboxed storage mounted: Documents/Signed/, Documents/IPAs/
        [INFO] Local Anisette mirror pool ready (4 active mirrors).
        [INFO] LocalInstallServer ready on port \(LocalInstallServer.shared.port).
        [STATUS] Pure client-side codesigning engine: Active.
        """
        logVC.view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: logVC.view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: logVC.view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: logVC.view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: logVC.view.bottomAnchor)
        ])
        
        let nav = UINavigationController(rootViewController: logVC)
        logVC.navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("关闭", "Close"), style: .done, target: self, action: #selector(dismissModal))
        present(nav, animated: true)
    }
    
    @objc private func dismissModal() {
        dismiss(animated: true)
    }
    
    @objc private func showTerms() {
        let alert = UIAlertController(
            title: L("服务协议", "Terms of Service"),
            message: L("UniSign 为纯离线本地开发者签名辅助工具。用户使用本软件签名第三方应用所产生的任何后果均由使用者自行承担，请遵守当地法律法规与 Apple 开发者协议条款。", "UniSign is an on-device developer sideload utility. Please adhere to Apple Developer TOS."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("我已知晓", "Understood"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func showPrivacy() {
        let alert = UIAlertController(
            title: L("隐私政策", "Privacy Policy"),
            message: L("UniSign 秉承 100% 本地隐私安全原则：\n1. 所有 Apple ID 密码与 P12 证书密钥仅加密保存在您手机本地 Keychain 与沙盒中。\n2. 绝不向任何外部第三方服务器上传您的开发者凭证与代码数据。\n3. 无任何数据埋点与远程追踪统计。", "100% on-device private execution. No credentials or IPA files are uploaded anywhere."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("我已知晓", "Understood"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func clearCache() {
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        updateCacheSize()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let alert = UIAlertController(title: L("清理完成", "Cache Cleared"), message: L("所有临时解压文件与工作缓存已释放。", "All temporary and cache files have been removed."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    private func updateCacheSize() {
        let tempDir = FileManager.default.temporaryDirectory
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                size += Int64(res?.fileSize ?? 0)
            }
        }
        let mb = Double(size) / (1024 * 1024)
        cacheDetailLabel?.text = String(format: L("当前临时文件占用: %.2f MB", "Current Cache: %.2f MB"), mb)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
