import UIKit

public class SettingsViewController: UIViewController {
    
    private let languageSegment = UISegmentedControl(items: ["简体中文", "English"])
    private let anisetteField = UITextField()
    private let portField = UITextField()
    private let clearCacheButton = UIButton(type: .system)
    private let cacheSizeLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    
    // Titles for dynamic reload
    private let languageTitle = UILabel()
    private let anisetteTitle = UILabel()
    private let portTitle = UILabel()
    private let cacheTitle = UILabel()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        updateTexts()
        updateCacheSize()
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // 0. Language Switcher
        languageTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(languageTitle)
        
        languageSegment.selectedSegmentIndex = LanguageManager.shared.currentLanguage == .chinese ? 0 : 1
        languageSegment.addTarget(self, action: #selector(languageSegmentChanged), for: .valueChanged)
        stack.addArrangedSubview(languageSegment)
        
        // 1. Anisette Server
        anisetteTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(anisetteTitle)
        
        anisetteField.text = AnisetteClient.shared.serverURL.absoluteString
        anisetteField.borderStyle = .roundedRect
        anisetteField.autocapitalizationType = .none
        stack.addArrangedSubview(anisetteField)
        
        // 2. Local Server Port
        portTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(portTitle)
        
        portField.text = "\(LocalInstallServer.shared.port)"
        portField.borderStyle = .roundedRect
        portField.keyboardType = .numberPad
        stack.addArrangedSubview(portField)
        
        // 3. Clear Cache
        cacheTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(cacheTitle)
        
        cacheSizeLabel.font = .systemFont(ofSize: 13)
        cacheSizeLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(cacheSizeLabel)
        
        clearCacheButton.backgroundColor = .systemRed
        clearCacheButton.setTitleColor(.white, for: .normal)
        clearCacheButton.layer.cornerRadius = 10
        clearCacheButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        clearCacheButton.addTarget(self, action: #selector(clearCache), for: .touchUpInside)
        stack.addArrangedSubview(clearCacheButton)
        
        // 4. Save Button
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        saveButton.addTarget(self, action: #selector(saveSettings), for: .touchUpInside)
        stack.addArrangedSubview(saveButton)
    }
    
    @objc private func languageDidChange() {
        updateTexts()
    }
    
    private func updateTexts() {
        title = L("系统设置", "Settings")
        languageTitle.text = L("软件语言 (Language)", "Application Language")
        anisetteTitle.text = L("Anisette 认证服务器 (用于 Apple ID 2FA 登录)", "Anisette Server (for Apple ID 2FA)")
        portTitle.text = L("本地安装 Web 服务端口 (itms-services OTA)", "Local Server Port (OTA Install)")
        cacheTitle.text = L("沙盒存储与缓存占用", "Storage & Cache")
        clearCacheButton.setTitle(L("清理临时解压与工作缓存", "Clear Temporary & Cache Files"), for: .normal)
        saveButton.setTitle(L("保存设置", "Save Settings"), for: .normal)
    }
    
    @objc private func languageSegmentChanged() {
        LanguageManager.shared.currentLanguage = languageSegment.selectedSegmentIndex == 0 ? .chinese : .english
    }
    
    @objc private func saveSettings() {
        if let urlStr = anisetteField.text, let url = URL(string: urlStr) {
            AnisetteClient.shared.serverURL = url
        }
        if let portStr = portField.text, let portVal = UInt16(portStr) {
            LocalInstallServer.shared.port = portVal
        }
        
        let alert = UIAlertController(
            title: L("设置已保存", "Settings Saved"),
            message: L("参数已成功更新并生效。", "Configuration has been saved."),
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
        
        let alert = UIAlertController(
            title: L("缓存已清理", "Cache Cleared"),
            message: L("所有临时工作文件与解压缓存已全部释放。", "All temporary working files have been purged."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    private func updateCacheSize() {
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(atPath: tempDir.path) {
            var totalSize: UInt64 = 0
            for file in files {
                let path = tempDir.appendingPathComponent(file).path
                if let attr = try? FileManager.default.attributesOfItem(atPath: path) {
                    totalSize += attr[.size] as? UInt64 ?? 0
                }
            }
            let mb = Double(totalSize) / (1024.0 * 1024.0)
            cacheSizeLabel.text = String(format: L("当前缓存占用: %.2f MB", "Cache Size: %.2f MB"), mb)
        } else {
            cacheSizeLabel.text = L("当前缓存占用: 0 MB", "Cache Size: 0 MB")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
