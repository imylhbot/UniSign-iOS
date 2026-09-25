import UIKit

/// Combined Application & Advanced Signing Configuration Controller
/// Faithfully designed after modern card-based sideload tools
public class SigningConfigViewController: UIViewController, UITextFieldDelegate {
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    
    // MARK: - Node / Anisette Section
    private let nodeCard = CardView()
    private var nodeRows: [UIView] = []
    private var nodeRadioButtons: [UIButton] = []
    private var nodeLatencyLabels: [UILabel] = []
    private var nodeStatusBadges: [UIImageView] = []
    
    private struct NodeItem {
        let flag: String
        let name: String
        let host: String
        let url: String
    }
    
    private let nodes: [NodeItem] = [
        NodeItem(flag: "🇭🇰", name: "HK 香港节点", host: "anisette.apsteam.top", url: "https://anisette.apsteam.top/"),
        NodeItem(flag: "☁️", name: "CF 全球 CDN", host: "ani.sidestore.io", url: "https://ani.sidestore.io/"),
        NodeItem(flag: "🇨🇳", name: "GZ 广州节点", host: "anisette.niceios.com", url: "https://anisette.niceios.com/"),
        NodeItem(flag: "🇯🇵", name: "JP 东京节点", host: "side.dhinak.net", url: "https://side.dhinak.net/ani/")
    ]
    
    // MARK: - Template Section
    private let templateCard = CardView()
    private let templateTextField = UITextField()
    private let previewLabel = UILabel()
    private let chipsStack = UIStackView()
    
    // MARK: - Signing Config Section
    private let signConfigCard = CardView()
    private let compressionSegment = UISegmentedControl(items: [
        L("快速", "Fast"),
        L("标准", "Standard"),
        L("最高", "Max")
    ])
    
    private let autoInstallSwitch = UISwitch()
    private let directInjectSwitch = UISwitch()
    private let removeURLSchemesSwitch = UISwitch()
    private let fixWhiteIconSwitch = UISwitch()
    private let fixDarkIconSwitch = UISwitch()
    private let removeEmbeddedSwitch = UISwitch()
    private let removeWatchSwitch = UISwitch()
    private let enableFileSharingSwitch = UISwitch()
    private let appendSignedSuffixSwitch = UISwitch()
    
    // MARK: - File Management Section
    private let fileManageCard = CardView()
    private let autoImportSwitch = UISwitch()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        title = L("应用配置", "App Config")
        
        setupUI()
        loadPreferences()
        updatePreview()
        pingAllNodes()
        
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    @objc private func languageDidChange() {
        title = L("应用配置", "App Config")
        compressionSegment.setTitle(L("快速", "Fast"), forSegmentAt: 0)
        compressionSegment.setTitle(L("标准", "Standard"), forSegmentAt: 1)
        compressionSegment.setTitle(L("最高", "Max"), forSegmentAt: 2)
        updatePreview()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        stack.axis = .vertical
        stack.spacing = 20
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
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        setupNodeCard()
        setupTemplateCard()
        setupSigningConfigCard()
        setupFileManageCard()
    }
    
    // MARK: - 1. Node Card
    private func setupNodeCard() {
        let cardStack = makeCardStack(in: nodeCard)
        
        let headerLabel = UILabel()
        headerLabel.text = L("认证与安装节点", "Nodes & Local Server")
        headerLabel.font = .systemFont(ofSize: 17, weight: .bold)
        cardStack.addArrangedSubview(headerLabel)
        
        // Option 0: Auto (Lowest latency)
        let autoRow = makeNodeRowView(
            index: 0,
            title: L("自动 (低延迟优先)", "Auto (Lowest Latency)"),
            subtitle: L("按实际响应速度自动选择最优节点", "Automatically select the fastest mirror"),
            isRadio: true
        )
        cardStack.addArrangedSubview(autoRow)
        
        // Node items
        for (idx, node) in nodes.enumerated() {
            let rowIdx = idx + 1
            let row = makeNodeRowView(
                index: rowIdx,
                title: "\(node.flag)  \(node.name)",
                subtitle: node.host,
                isRadio: true,
                hasPing: true
            )
            cardStack.addArrangedSubview(row)
        }
        
        // Local offline option
        let localRow = makeNodeRowView(
            index: nodes.count + 1,
            title: L("本地安装 (离线模式)", "Local Install (Offline)"),
            subtitle: L("完全离线，直接在设备端进行签名", "Pure offline synthesis, no network required"),
            isRadio: true
        )
        cardStack.addArrangedSubview(localRow)
        
        stack.addArrangedSubview(nodeCard)
    }
    
    private func makeNodeRowView(index: Int, title: String, subtitle: String, isRadio: Bool, hasPing: Bool = false) -> UIView {
        let rowView = UIView()
        rowView.tag = index
        rowView.translatesAutoresizingMaskIntoConstraints = false
        rowView.backgroundColor = UIColor.secondarySystemGroupedBackground
        rowView.layer.cornerRadius = 12
        rowView.layer.borderWidth = 1
        rowView.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(nodeRowTapped(_:)))
        rowView.addGestureRecognizer(tap)
        rowView.isUserInteractionEnabled = true
        
        let radioBtn = UIButton(type: .custom)
        radioBtn.tag = index
        radioBtn.setImage(UIImage(systemName: "circle"), for: .normal)
        radioBtn.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        radioBtn.tintColor = UniSignTheme.primaryColor
        radioBtn.translatesAutoresizingMaskIntoConstraints = false
        radioBtn.addTarget(self, action: #selector(radioBtnTapped(_:)), for: .touchUpInside)
        rowView.addSubview(radioBtn)
        nodeRadioButtons.append(radioBtn)
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = 3
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(labelStack)
        
        let tLabel = UILabel()
        tLabel.text = title
        tLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        labelStack.addArrangedSubview(tLabel)
        
        let sLabel = UILabel()
        sLabel.text = subtitle
        sLabel.font = .systemFont(ofSize: 12)
        sLabel.textColor = .secondaryLabel
        labelStack.addArrangedSubview(sLabel)
        
        let pingStack = UIStackView()
        pingStack.axis = .horizontal
        pingStack.spacing = 6
        pingStack.alignment = .center
        pingStack.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(pingStack)
        
        if hasPing {
            let latLabel = UILabel()
            latLabel.text = L("测速中...", "Testing...")
            latLabel.font = .systemFont(ofSize: 12, weight: .medium)
            latLabel.textColor = .secondaryLabel
            pingStack.addArrangedSubview(latLabel)
            nodeLatencyLabels.append(latLabel)
            
            let statusIcon = UIImageView(image: UIImage(systemName: "circle.fill"))
            statusIcon.tintColor = .systemGray
            statusIcon.contentMode = .scaleAspectFit
            statusIcon.widthAnchor.constraint(equalToConstant: 14).isActive = true
            statusIcon.heightAnchor.constraint(equalToConstant: 14).isActive = true
            pingStack.addArrangedSubview(statusIcon)
            nodeStatusBadges.append(statusIcon)
        }
        
        NSLayoutConstraint.activate([
            rowView.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            
            radioBtn.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 12),
            radioBtn.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            radioBtn.widthAnchor.constraint(equalToConstant: 24),
            radioBtn.heightAnchor.constraint(equalToConstant: 24),
            
            labelStack.leadingAnchor.constraint(equalTo: radioBtn.trailingAnchor, constant: 12),
            labelStack.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: pingStack.leadingAnchor, constant: -8),
            labelStack.topAnchor.constraint(equalTo: rowView.topAnchor, constant: 10),
            labelStack.bottomAnchor.constraint(equalTo: rowView.bottomAnchor, constant: -10),
            
            pingStack.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            pingStack.centerYAnchor.constraint(equalTo: rowView.centerYAnchor)
        ])
        
        nodeRows.append(rowView)
        return rowView
    }
    
    // MARK: - 2. Package Filename Template Card
    private func setupTemplateCard() {
        let cardStack = makeCardStack(in: templateCard)
        
        let titleLabel = UILabel()
        titleLabel.text = L("打包文件名", "Output Filename Template")
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        cardStack.addArrangedSubview(titleLabel)
        
        // Monospace Text Box
        let box = UIView()
        box.backgroundColor = UIColor.secondarySystemGroupedBackground
        box.layer.cornerRadius = 12
        box.layer.borderWidth = 1
        box.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
        box.translatesAutoresizingMaskIntoConstraints = false
        
        templateTextField.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        templateTextField.borderStyle = .none
        templateTextField.autocapitalizationType = .none
        templateTextField.autocorrectionType = .no
        templateTextField.delegate = self
        templateTextField.addTarget(self, action: #selector(templateChanged), for: .editingChanged)
        templateTextField.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(templateTextField)
        
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: 48),
            templateTextField.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            templateTextField.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            templateTextField.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        cardStack.addArrangedSubview(box)
        
        // Preview Label
        previewLabel.font = .systemFont(ofSize: 13, weight: .medium)
        previewLabel.textColor = .secondaryLabel
        previewLabel.numberOfLines = 0
        cardStack.addArrangedSubview(previewLabel)
        
        // Chip Tag Label
        let tagHeader = UILabel()
        tagHeader.text = L("可用变量", "Available Variables")
        tagHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        tagHeader.textColor = .secondaryLabel
        cardStack.addArrangedSubview(tagHeader)
        
        // Chip Flow Rows
        let chipTags = [
            ["[name]", "[version]", "[identifier]", "[timestamp]"],
            ["[displayName]", "[bundleId]"],
            ["{yyyyMMdd}", "{HHmm}", "{yy-MM-dd_HHmm}"]
        ]
        
        for row in chipTags {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 8
            rowStack.distribution = .fillProportionally
            
            for tag in row {
                let chip = UIButton(type: .system)
                chip.setTitle(tag, for: .normal)
                chip.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
                chip.setTitleColor(UniSignTheme.primaryColor, for: .normal)
                chip.backgroundColor = UniSignTheme.primaryColor.withAlphaComponent(0.08)
                chip.layer.cornerRadius = 8
                chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
                chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
                rowStack.addArrangedSubview(chip)
            }
            cardStack.addArrangedSubview(rowStack)
        }
        
        // Help note
        let note = UILabel()
        note.text = L("花括号里写任意 DateFormatter 格式，签名时会替换成当时的时间", "Braces {...} support any DateFormatter token, replaced during signing")
        note.font = .systemFont(ofSize: 12)
        note.textColor = .tertiaryLabel
        note.numberOfLines = 0
        cardStack.addArrangedSubview(note)
        
        // Restore Default Button
        let resetBtn = UIButton(type: .system)
        resetBtn.setTitle(L("恢复默认模板", "Restore Default"), for: .normal)
        resetBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        resetBtn.contentHorizontalAlignment = .left
        resetBtn.addTarget(self, action: #selector(resetTemplate), for: .touchUpInside)
        cardStack.addArrangedSubview(resetBtn)
        
        stack.addArrangedSubview(templateCard)
    }
    
    // MARK: - 3. Signing Advanced Config Card
    private func setupSigningConfigCard() {
        let cardStack = makeCardStack(in: signConfigCard)
        
        let titleLabel = UILabel()
        titleLabel.text = L("签名配置", "Signing Options")
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        cardStack.addArrangedSubview(titleLabel)
        
        // Compression Level
        let compLabel = UILabel()
        compLabel.text = L("压缩级别", "Compression Level")
        compLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        cardStack.addArrangedSubview(compLabel)
        
        compressionSegment.heightAnchor.constraint(equalToConstant: 34).isActive = true
        compressionSegment.addTarget(self, action: #selector(compressionChanged), for: .valueChanged)
        cardStack.addArrangedSubview(compressionSegment)
        
        let compHint = UILabel()
        compHint.text = L("等级越高文件越小，但打包耗时越长", "Higher compression results in smaller files but takes longer")
        compHint.font = .systemFont(ofSize: 12)
        compHint.textColor = .secondaryLabel
        cardStack.addArrangedSubview(compHint)
        
        let sep = makeSeparator()
        cardStack.addArrangedSubview(sep)
        
        // Switch options
        let switches: [(String, String, UISwitch, Selector)] = [
            (L("签名完成安装", "Install After Signing"), L("签名完成后不弹提示，直接安装", "Directly trigger installation after signing"), autoInstallSwitch, #selector(switchChanged)),
            (L("直接注入插件", "Direct Tweak Injection"), L("不经过 LoadControl，直接写入 Mach-O", "Direct LC_LOAD_DYLIB Mach-O injection"), directInjectSwitch, #selector(switchChanged)),
            (L("移除应用跳转", "Remove URL Schemes"), L("移除跳转配置，避免抢占其他应用", "Strip CFBundleURLTypes to avoid scheme hijacking"), removeURLSchemesSwitch, #selector(switchChanged)),
            (L("修复白色图标", "Fix White Icon"), L("重写图标引用，修复图标变白色", "Rewrite CFBundleIcons CFBundlePrimaryIcon files"), fixWhiteIconSwitch, #selector(switchChanged)),
            (L("修复深色图标", "Fix Dark Mode Icon"), L("恢复 iOS 18 自动深浅色切换", "Preserve iOS 18 dynamic dark icon"), fixDarkIconSwitch, #selector(switchChanged)),
            (L("移除 Embedded", "Remove Embedded Profile"), L("签名产物不写 embedded.mobileprovision，适配 TrollStore", "Skip profile for TrollStore usage"), removeEmbeddedSwitch, #selector(switchChanged)),
            (L("移除 Watch 组件", "Remove Watch Apps"), L("签名产物删除 Watch App 与 WatchPlaceholder，减少安装失败", "Strip Watch components to avoid signature fails"), removeWatchSwitch, #selector(switchChanged)),
            (L("开启文件访问", "Enable File Sharing"), L("新工作区默认在文件 App 直接访问应用文档", "Enable UIFileSharingEnabled in Files app"), enableFileSharingSwitch, #selector(switchChanged)),
            (L("附加 -signed 后缀", "Append -signed Suffix"), L("关闭后输出文件名完全等于上方模板渲染结果", "Add -signed tag to output IPA name"), appendSignedSuffixSwitch, #selector(switchChanged))
        ]
        
        for item in switches {
            let row = makeSwitchRow(title: item.0, subtitle: item.1, toggle: item.2, action: item.3)
            cardStack.addArrangedSubview(row)
        }
        
        stack.addArrangedSubview(signConfigCard)
    }
    
    // MARK: - 4. File Management Card
    private func setupFileManageCard() {
        let cardStack = makeCardStack(in: fileManageCard)
        
        let titleLabel = UILabel()
        titleLabel.text = L("文件管理", "File Management")
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        cardStack.addArrangedSubview(titleLabel)
        
        let row = makeSwitchRow(
            title: L("下载完成后导入工作区", "Auto-Import Downloaded IPAs"),
            subtitle: L("下载到 .ipa/.tipa 后自动入库到项目", "Automatically add imported files to Library"),
            toggle: autoImportSwitch,
            action: #selector(switchChanged)
        )
        cardStack.addArrangedSubview(row)
        
        stack.addArrangedSubview(fileManageCard)
    }
    
    private func makeSwitchRow(title: String, subtitle: String, toggle: UISwitch, action: Selector) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = 3
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(labelStack)
        
        let tLabel = UILabel()
        tLabel.text = title
        tLabel.font = .systemFont(ofSize: 15, weight: .medium)
        labelStack.addArrangedSubview(tLabel)
        
        let sLabel = UILabel()
        sLabel.text = subtitle
        sLabel.font = .systemFont(ofSize: 12)
        sLabel.textColor = .secondaryLabel
        labelStack.addArrangedSubview(sLabel)
        
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.onTintColor = UniSignTheme.primaryColor
        toggle.addTarget(self, action: action, for: .valueChanged)
        row.addSubview(toggle)
        
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            labelStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            labelStack.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -12),
            labelStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 6),
            labelStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -6),
            
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }
    
    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.2)
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return sep
    }
    
    private func makeCardStack(in card: CardView) -> UIStackView {
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 14
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
        return cardStack
    }
    
    // MARK: - Actions & Logic
    private func loadPreferences() {
        let prefs = SigningPreferences.shared
        selectNode(at: prefs.selectedNodeIndex)
        
        templateTextField.text = prefs.filenameTemplate
        compressionSegment.selectedSegmentIndex = prefs.compressionLevel
        
        autoInstallSwitch.isOn = prefs.autoInstallAfterSigning
        directInjectSwitch.isOn = prefs.directInjectPlugin
        removeURLSchemesSwitch.isOn = prefs.removeURLSchemes
        fixWhiteIconSwitch.isOn = prefs.fixWhiteIcon
        fixDarkIconSwitch.isOn = prefs.fixDarkIcon
        removeEmbeddedSwitch.isOn = prefs.removeEmbeddedProvision
        removeWatchSwitch.isOn = prefs.removeWatchApp
        enableFileSharingSwitch.isOn = prefs.enableFileSharing
        appendSignedSuffixSwitch.isOn = prefs.appendSignedSuffix
        autoImportSwitch.isOn = prefs.autoImportDownloadedIPA
    }
    
    private func selectNode(at index: Int) {
        for (i, btn) in nodeRadioButtons.enumerated() {
            btn.isSelected = (i == index)
        }
        for (i, row) in nodeRows.enumerated() {
            if i == index {
                row.layer.borderColor = UniSignTheme.primaryColor.withAlphaComponent(0.6).cgColor
                row.backgroundColor = UniSignTheme.primaryColor.withAlphaComponent(0.04)
            } else {
                row.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
                row.backgroundColor = UIColor.secondarySystemGroupedBackground
            }
        }
        SigningPreferences.shared.selectedNodeIndex = index
        
        if index > 0 && index <= nodes.count {
            AnisetteClient.shared.setCustomURLString(nodes[index - 1].url)
        } else {
            AnisetteClient.shared.setCustomURLString("")
        }
    }
    
    @objc private func nodeRowTapped(_ gesture: UITapGestureRecognizer) {
        if let idx = gesture.view?.tag {
            selectNode(at: idx)
        }
    }
    
    @objc private func radioBtnTapped(_ sender: UIButton) {
        selectNode(at: sender.tag)
    }
    
    private func pingAllNodes() {
        for (i, node) in nodes.enumerated() {
            guard i < nodeLatencyLabels.count, i < nodeStatusBadges.count else { continue }
            let latLabel = nodeLatencyLabels[i]
            let badge = nodeStatusBadges[i]
            
            AnisetteClient.shared.testServerLatency(urlString: node.url) { ms in
                DispatchQueue.main.async {
                    if let ms = ms {
                        latLabel.text = "\(ms) ms"
                        latLabel.textColor = ms < 300 ? .systemGreen : (ms < 1000 ? .systemOrange : .systemRed)
                        badge.image = UIImage(systemName: "checkmark.circle.fill")
                        badge.tintColor = .systemGreen
                    } else {
                        latLabel.text = L("异常", "Error")
                        latLabel.textColor = .systemRed
                        badge.image = UIImage(systemName: "exclamationmark.circle.fill")
                        badge.tintColor = .systemRed
                    }
                }
            }
        }
    }
    
    @objc private func templateChanged() {
        SigningPreferences.shared.filenameTemplate = templateTextField.text ?? ""
        updatePreview()
    }
    
    @objc private func chipTapped(_ sender: UIButton) {
        guard let tag = sender.title(for: .normal) else { return }
        let current = templateTextField.text ?? ""
        templateTextField.text = current + tag
        templateChanged()
    }
    
    @objc private func resetTemplate() {
        templateTextField.text = "[name]_[version]_[timestamp]-UniSign"
        templateChanged()
    }
    
    private func updatePreview() {
        let sample = PlistModifier.formatOutputFilename(
            template: templateTextField.text ?? "",
            appName: "WeChat",
            bundleId: "com.tencent.xin",
            version: "8.0.48",
            displayName: "微信",
            appendSignedSuffix: appendSignedSuffixSwitch.isOn
        )
        previewLabel.text = "\(L("预览：", "Preview: "))\(sample)"
    }
    
    @objc private func compressionChanged() {
        SigningPreferences.shared.compressionLevel = compressionSegment.selectedSegmentIndex
    }
    
    @objc private func switchChanged() {
        let prefs = SigningPreferences.shared
        prefs.autoInstallAfterSigning = autoInstallSwitch.isOn
        prefs.directInjectPlugin = directInjectSwitch.isOn
        prefs.removeURLSchemes = removeURLSchemesSwitch.isOn
        prefs.fixWhiteIcon = fixWhiteIconSwitch.isOn
        prefs.fixDarkIcon = fixDarkIconSwitch.isOn
        prefs.removeEmbeddedProvision = removeEmbeddedSwitch.isOn
        prefs.removeWatchApp = removeWatchSwitch.isOn
        prefs.enableFileSharing = enableFileSharingSwitch.isOn
        prefs.appendSignedSuffix = appendSignedSuffixSwitch.isOn
        prefs.autoImportDownloadedIPA = autoImportSwitch.isOn
        
        updatePreview()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
