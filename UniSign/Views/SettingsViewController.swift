import UIKit

public class SettingsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    
    // Cards
    private let langCard = CardView()
    private let languageSegment = UISegmentedControl(items: ["简体中文", "English"])
    
    private let anisetteCard = CardView()
    private let anisetteField = UITextField()
    private let testLatencyBtn = GradientButton(title: "", style: .secondaryGray, icon: UIImage(systemName: "bolt.fill"))
    private let latencyLabel = UILabel()
    private let mirrorStack = UIStackView()
    
    private let portCard = CardView()
    private let portField = UITextField()
    
    private let cacheCard = CardView()
    private let cacheSizeLabel = UILabel()
    private let clearCacheButton = GradientButton(title: "", style: .destructive, icon: UIImage(systemName: "trash.fill"))
    
    private let aboutCard = CardView()
    private let saveButton = GradientButton(title: "", style: .primaryCyber, icon: UIImage(systemName: "checkmark.circle.fill"))
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupUI()
        updateTexts()
        updateCacheSize()
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        stack.axis = .vertical
        stack.spacing = 16
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
        
        setupLanguageCard()
        setupAnisetteCard()
        setupPortCard()
        setupCacheCard()
        setupAboutCard()
        
        saveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        saveButton.addTarget(self, action: #selector(saveSettings), for: .touchUpInside)
        stack.addArrangedSubview(saveButton)
    }
    
    private func setupLanguageCard() {
        let cardStack = makeCardStack(in: langCard)
        let title = UILabel()
        title.text = L("软件语言 (Language)", "Application Language")
        title.font = .systemFont(ofSize: 15, weight: .bold)
        cardStack.addArrangedSubview(title)
        
        languageSegment.selectedSegmentIndex = LanguageManager.shared.currentLanguage == .chinese ? 0 : 1
        languageSegment.heightAnchor.constraint(equalToConstant: 34).isActive = true
        languageSegment.addTarget(self, action: #selector(languageSegmentChanged), for: .valueChanged)
        cardStack.addArrangedSubview(languageSegment)
        stack.addArrangedSubview(langCard)
    }
    
    private func setupAnisetteCard() {
        let cardStack = makeCardStack(in: anisetteCard)
        let title = UILabel()
        title.text = L("Anisette 认证服务器 (Apple ID 2FA)", "Anisette Authentication Server")
        title.font = .systemFont(ofSize: 15, weight: .bold)
        cardStack.addArrangedSubview(title)
        
        let desc = UILabel()
        desc.text = L("用于在设备端与 Apple GrandSlam 认证握手，内置智能节点故障自动转移与离线本地容灾。", "Provides cryptographic headers for GrandSlam auth with multi-mirror failover.")
        desc.font = .systemFont(ofSize: 12)
        desc.textColor = .secondaryLabel
        desc.numberOfLines = 0
        cardStack.addArrangedSubview(desc)
        
        anisetteField.text = AnisetteClient.shared.serverURL.absoluteString
        anisetteField.borderStyle = .roundedRect
        anisetteField.autocapitalizationType = .none
        anisetteField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        cardStack.addArrangedSubview(anisetteField)
        
        // Fast Mirror Buttons
        let mirrorRow = UIStackView()
        mirrorRow.axis = .horizontal
        mirrorRow.spacing = 8
        mirrorRow.distribution = .fillEqually
        
        let mirrors = [
            ("亚太节点", "https://anisette.apsteam.top/"),
            ("SideStore", "https://ani.sidestore.io/"),
            ("国内节点", "https://anisette.niceios.com/")
        ]
        
        for (name, urlStr) in mirrors {
            let btn = UIButton(type: .system)
            btn.setTitle(name, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            btn.backgroundColor = UIColor.label.withAlphaComponent(0.06)
            btn.layer.cornerRadius = 8
            btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
            btn.addAction(UIAction { [weak self] _ in
                self?.anisetteField.text = urlStr
                self?.testLatency()
            }, for: .touchUpInside)
            mirrorRow.addArrangedSubview(btn)
        }
        cardStack.addArrangedSubview(mirrorRow)
        
        let testRow = UIStackView()
        testRow.axis = .horizontal
        testRow.spacing = 10
        testRow.alignment = .center
        
        testLatencyBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        testLatencyBtn.addTarget(self, action: #selector(testLatency), for: .touchUpInside)
        testRow.addArrangedSubview(testLatencyBtn)
        
        latencyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        latencyLabel.textColor = .secondaryLabel
        testRow.addArrangedSubview(latencyLabel)
        cardStack.addArrangedSubview(testRow)
        
        stack.addArrangedSubview(anisetteCard)
    }
    
    private func setupPortCard() {
        let cardStack = makeCardStack(in: portCard)
        let title = UILabel()
        title.text = L("本地安装 Web 服务端口 (OTA)", "Local Web Server Port (OTA)")
        title.font = .systemFont(ofSize: 15, weight: .bold)
        cardStack.addArrangedSubview(title)
        
        portField.text = "\(LocalInstallServer.shared.port)"
        portField.borderStyle = .roundedRect
        portField.keyboardType = .numberPad
        portField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        cardStack.addArrangedSubview(portField)
        stack.addArrangedSubview(portCard)
    }
    
    private func setupCacheCard() {
        let cardStack = makeCardStack(in: cacheCard)
        let title = UILabel()
        title.text = L("沙盒存储与缓存占用", "Storage & Cache")
        title.font = .systemFont(ofSize: 15, weight: .bold)
        cardStack.addArrangedSubview(title)
        
        cacheSizeLabel.font = .systemFont(ofSize: 13)
        cacheSizeLabel.textColor = .secondaryLabel
        cardStack.addArrangedSubview(cacheSizeLabel)
        
        clearCacheButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        clearCacheButton.addTarget(self, action: #selector(clearCache), for: .touchUpInside)
        cardStack.addArrangedSubview(clearCacheButton)
        stack.addArrangedSubview(cacheCard)
    }
    
    private func setupAboutCard() {
        let cardStack = makeCardStack(in: aboutCard)
        let title = UILabel()
        title.text = "UniSign iOS v1.0.0"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        cardStack.addArrangedSubview(title)
        
        let desc = UILabel()
        desc.text = L(
            "纯设备端免越狱 IPA 签名与深度定制工具。\n支持多 Apple ID 切换、7天免费证书一键续期、3-App 配额追踪、Mach-O 插件注入与文件共享权限开启。",
            "On-device sideload & tweak injection toolkit for iOS.\nFeatures multi-Apple ID management, 1-click renewal, 3-app quota tracker, and Mach-O modification."
        )
        desc.font = .systemFont(ofSize: 12)
        desc.textColor = .secondaryLabel
        desc.numberOfLines = 0
        cardStack.addArrangedSubview(desc)
        stack.addArrangedSubview(aboutCard)
    }
    
    private func makeCardStack(in card: CardView) -> UIStackView {
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 10
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return cardStack
    }
    
    @objc private func languageDidChange() {
        updateTexts()
    }
    
    private func updateTexts() {
        title = L("系统设置", "Settings")
        testLatencyBtn.setTitle(L("测试延迟 (Ping)", "Test Latency"), for: .normal)
        clearCacheButton.setTitle(L("清理临时解压与工作缓存", "Clear Cache & Temp Files"), for: .normal)
        saveButton.setTitle(L("保存设置", "Save Settings"), for: .normal)
    }
    
    @objc private func languageSegmentChanged() {
        LanguageManager.shared.currentLanguage = languageSegment.selectedSegmentIndex == 0 ? .chinese : .english
    }
    
    @objc private func testLatency() {
        guard let urlStr = anisetteField.text, !urlStr.isEmpty else { return }
        latencyLabel.text = L("正在测速...", "Testing...")
        latencyLabel.textColor = .secondaryLabel
        testLatencyBtn.setLoading(true)
        
        AnisetteClient.shared.testServerLatency(urlString: urlStr) { [weak self] ms in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.testLatencyBtn.setLoading(false)
                if let ms = ms {
                    self.latencyLabel.text = "\(ms) ms"
                    self.latencyLabel.textColor = ms < 300 ? .systemGreen : .systemOrange
                } else {
                    self.latencyLabel.text = L("超时 (将自动采用离线本地容灾)", "Offline (local synthesis will be used)")
                    self.latencyLabel.textColor = .systemRed
                }
            }
        }
    }
    
    @objc private func saveSettings() {
        if let urlStr = anisetteField.text {
            AnisetteClient.shared.setCustomURLString(urlStr)
        }
        if let portStr = portField.text, let portVal = UInt16(portStr) {
            LocalInstallServer.shared.port = portVal
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let alert = UIAlertController(
            title: L("设置已保存", "Settings Saved"),
            message: L("参数已成功更新并生效。", "Configuration has been saved successfully."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
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
        cacheSizeLabel.text = String(format: L("当前临时文件占用: %.2f MB", "Current Cache Usage: %.2f MB"), mb)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
