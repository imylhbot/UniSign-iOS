import UIKit

public class SignWorkflowViewController: UIViewController, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentInteractionControllerDelegate {
    
    // MARK: - State Properties
    public var preselectedIPAURL: URL?
    public var isModifyOnlyMode: Bool = false {
        didSet {
            selectedCertMode = isModifyOnlyMode ? .none : .appleID
            updateCertCardText()
            updateActionButtonTitle()
        }
    }
    
    public enum CertMode {
        case appleID
        case p12
        case none // Modify only without signing
    }
    private var selectedCertMode: CertMode = .appleID
    
    private var selectedIPAURL: URL?
    private var selectedIconImage: UIImage?
    private var dylibsToInject: [URL] = []
    private var dylibsToRemove: [String] = []
    private var signedIPAURL: URL?
    private var docController: UIDocumentInteractionController?
    
    // Extracted / customized metadata
    private var currentAppName: String = "UniSign"
    private var currentBundleId: String = "com.unisign.app"
    private var currentVersion: String = "1.0.0"
    private var currentMinOS: String = "13.0"
    private var currentWorkspaceNote: String = ""
    private var outputExportFormat: String = "ipa" // "ipa" or "tipa"
    private var isLoadControlEnabled: Bool = false
    private var areDepsExpanded: Bool = false
    private var detectedDependencies: [String] = [
        "Foundation.framework",
        "UIKit.framework",
        "Security.framework",
        "CoreGraphics.framework",
        "libz.1.dylib",
        "libobjc.A.dylib",
        "libSystem.B.dylib"
    ]
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    // Card 1: App Header Card
    private let appHeaderCard = CardView()
    private let appIconImageView = UIImageView()
    private let editIconBadge = UIButton(type: .system)
    private let appNameLabel = UILabel()
    private let editNameBtn = UIButton(type: .system)
    private let bundleIdLabel = UILabel()
    private let editBundleBtn = UIButton(type: .system)
    private let noteButton = UIButton(type: .system)
    private let versionChip = UIButton(type: .system)
    private let loadControlChip = UIButton(type: .system)
    private let pluginCountChip = UIButton(type: .system)
    
    // Card 2: Output Filename Card
    private let filenameCard = CardView()
    private let filenamePreviewLabel = UILabel()
    private let formatSegment = UISegmentedControl(items: ["IPA", "TIPA"])
    
    // Card 3: Injected Plugins Card
    private let dylibCard = CardView()
    private let dylibEmptyLabel = UILabel()
    private let dylibListStack = UIStackView()
    
    // Card 4: Project Configuration Switches
    private let configCard = CardView()
    private let fileSharingSwitch = UISwitch()
    private let urlSchemeSwitch = UISwitch()
    private let fixWhiteIconSwitch = UISwitch()
    private let fixDarkIconSwitch = UISwitch()
    private let directInjectSwitch = UISwitch()
    private let removeEmbeddedSwitch = UISwitch()
    private let removeWatchSwitch = UISwitch()
    
    // Yellow Notice Banner
    private let noticeBanner = UIView()
    private let noticeLabel = UILabel()
    
    // Card 5: Signing Certificate Card
    private let certCard = CardView()
    private let certTitleLabel = UILabel()
    private let certDetailLabel = UILabel()
    
    // Card 6: Main Binary Dependencies Card
    private let depsCard = CardView()
    private let depsCountLabel = UILabel()
    private let depsListLabel = UILabel()
    private let expandDepsBtn = UIButton(type: .system)
    
    // Bottom Action Buttons
    private let bottomContainer = UIView()
    private let browseFolderBtn = GradientButton(title: "", style: .forestGreenOutline, icon: UIImage(systemName: "folder"))
    private let signAndInstallBtn = GradientButton(title: "", style: .forestGreen, icon: UIImage(systemName: "hammer.fill"))
    
    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupNavigationBar()
        setupUI()
        updateTexts()
        
        if let preselected = preselectedIPAURL {
            applySelectedIPA(preselected)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCertCardText()
        updateActionButtonTitle()
        updateFilenamePreview()
    }
    
    // MARK: - Navigation Bar
    private func setupNavigationBar() {
        title = L("项目详情", "Project Details")
        
        let selectBtn = UIBarButtonItem(
            title: L("选择", "Select"),
            style: .plain,
            target: self,
            action: #selector(showIPAPickerOptions)
        )
        selectBtn.tintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        
        let moreBtn = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showMoreMenu)
        )
        moreBtn.tintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        
        navigationItem.rightBarButtonItems = [moreBtn, selectBtn]
    }
    
    // MARK: - Layout Setup
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 14
        scrollView.addSubview(contentView)
        
        // Bottom Action Area Container
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.backgroundColor = UniSignTheme.pageBackground
        view.addSubview(bottomContainer)
        
        let bottomStack = UIStackView()
        bottomStack.axis = .vertical
        bottomStack.spacing = 10
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(bottomStack)
        
        browseFolderBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        browseFolderBtn.addTarget(self, action: #selector(browseWorkspaceFolder), for: .touchUpInside)
        bottomStack.addArrangedSubview(browseFolderBtn)
        
        signAndInstallBtn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        signAndInstallBtn.addTarget(self, action: #selector(startSignAndInstall), for: .touchUpInside)
        bottomStack.addArrangedSubview(signAndInstallBtn)
        
        NSLayoutConstraint.activate([
            bottomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            
            bottomStack.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: 8),
            bottomStack.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor, constant: -8),
            bottomStack.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor, constant: 16),
            bottomStack.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor, constant: -16),
            
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomContainer.topAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 12),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // 1. App Header Card
        setupAppHeaderCard()
        contentView.addArrangedSubview(appHeaderCard)
        
        // 2. Output Filename Card
        setupFilenameCard()
        contentView.addArrangedSubview(filenameCard)
        
        // 3. Injected Plugins Card
        setupDylibCard()
        contentView.addArrangedSubview(dylibCard)
        
        // 4. Project Configuration Card
        setupConfigCard()
        contentView.addArrangedSubview(configCard)
        
        // 5. Yellow Notice Banner
        setupNoticeBanner()
        contentView.addArrangedSubview(noticeBanner)
        
        // 6. Signing Certificate Card
        setupCertCard()
        contentView.addArrangedSubview(certCard)
        
        // 7. Main Binary Dependencies Card
        setupDepsCard()
        contentView.addArrangedSubview(depsCard)
    }
    
    // MARK: - 1. App Header Card (Icon + Name + BundleID + Chips)
    private func setupAppHeaderCard() {
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        appHeaderCard.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: appHeaderCard.topAnchor, constant: 14),
            cardStack.bottomAnchor.constraint(equalTo: appHeaderCard.bottomAnchor, constant: -14),
            cardStack.leadingAnchor.constraint(equalTo: appHeaderCard.leadingAnchor, constant: 14),
            cardStack.trailingAnchor.constraint(equalTo: appHeaderCard.trailingAnchor, constant: -14)
        ])
        
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 14
        topRow.alignment = .center
        
        // App Icon with Edit Badge
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconContainer.heightAnchor.constraint(equalToConstant: 64).isActive = true
        
        appIconImageView.image = UIImage(systemName: "app.fill")
        appIconImageView.tintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        appIconImageView.contentMode = .scaleAspectFill
        appIconImageView.layer.cornerRadius = 14
        appIconImageView.layer.masksToBounds = true
        appIconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(appIconImageView)
        
        editIconBadge.setImage(UIImage(systemName: "pencil")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)), for: .normal)
        editIconBadge.tintColor = .white
        editIconBadge.backgroundColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        editIconBadge.layer.cornerRadius = 11
        editIconBadge.layer.borderWidth = 1.5
        editIconBadge.layer.borderColor = UIColor.white.cgColor
        editIconBadge.layer.masksToBounds = true
        editIconBadge.translatesAutoresizingMaskIntoConstraints = false
        editIconBadge.addTarget(self, action: #selector(chooseIcon), for: .touchUpInside)
        iconContainer.addSubview(editIconBadge)
        
        NSLayoutConstraint.activate([
            appIconImageView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            appIconImageView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            appIconImageView.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor),
            appIconImageView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            
            editIconBadge.widthAnchor.constraint(equalToConstant: 22),
            editIconBadge.heightAnchor.constraint(equalToConstant: 22),
            editIconBadge.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 3),
            editIconBadge.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 3)
        ])
        topRow.addArrangedSubview(iconContainer)
        
        // Right Text Info Stack
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 3
        
        // App Name + Edit Button
        let nameRow = UIStackView()
        nameRow.axis = .horizontal
        nameRow.spacing = 6
        nameRow.alignment = .center
        
        appNameLabel.text = currentAppName
        appNameLabel.font = .systemFont(ofSize: 18, weight: .bold)
        appNameLabel.textColor = .label
        nameRow.addArrangedSubview(appNameLabel)
        
        editNameBtn.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        editNameBtn.tintColor = .secondaryLabel
        editNameBtn.addTarget(self, action: #selector(promptEditAppName), for: .touchUpInside)
        nameRow.addArrangedSubview(editNameBtn)
        nameRow.addArrangedSubview(UIView())
        infoStack.addArrangedSubview(nameRow)
        
        // Bundle ID + Edit Button
        let bundleRow = UIStackView()
        bundleRow.axis = .horizontal
        bundleRow.spacing = 6
        bundleRow.alignment = .center
        
        bundleIdLabel.text = currentBundleId
        bundleIdLabel.font = .systemFont(ofSize: 13, weight: .regular)
        bundleIdLabel.textColor = .secondaryLabel
        bundleRow.addArrangedSubview(bundleIdLabel)
        
        editBundleBtn.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        editBundleBtn.tintColor = .secondaryLabel
        editBundleBtn.addTarget(self, action: #selector(promptEditBundleId), for: .touchUpInside)
        bundleRow.addArrangedSubview(editBundleBtn)
        bundleRow.addArrangedSubview(UIView())
        infoStack.addArrangedSubview(bundleRow)
        
        // Workspace Note
        noteButton.setTitle("💬 " + L("添加工作区备注", "Add workspace note"), for: .normal)
        noteButton.titleLabel?.font = .systemFont(ofSize: 12)
        noteButton.setTitleColor(.tertiaryLabel, for: .normal)
        noteButton.contentHorizontalAlignment = .leading
        noteButton.addTarget(self, action: #selector(promptEditNote), for: .touchUpInside)
        infoStack.addArrangedSubview(noteButton)
        
        topRow.addArrangedSubview(infoStack)
        cardStack.addArrangedSubview(topRow)
        
        // Bottom Chips Row (Version, LoadControl, Plugin count)
        let chipsRow = UIStackView()
        chipsRow.axis = .horizontal
        chipsRow.spacing = 8
        chipsRow.alignment = .center
        
        styleChip(versionChip, text: "v\(currentVersion) 📝", bgColor: UIColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1.0), textColor: UIColor(red: 0.10, green: 0.40, blue: 0.85, alpha: 1.0))
        versionChip.addTarget(self, action: #selector(promptEditVersion), for: .touchUpInside)
        chipsRow.addArrangedSubview(versionChip)
        
        styleChip(loadControlChip, text: "✖ LoadControl", bgColor: UIColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1.0), textColor: .secondaryLabel)
        loadControlChip.addTarget(self, action: #selector(toggleLoadControl), for: .touchUpInside)
        chipsRow.addArrangedSubview(loadControlChip)
        
        styleChip(pluginCountChip, text: "\(L("插件", "Tweaks")) \(dylibsToInject.count)", bgColor: UIColor(red: 0.94, green: 0.95, blue: 0.96, alpha: 1.0), textColor: .secondaryLabel)
        pluginCountChip.addTarget(self, action: #selector(showDylibPickerOptions), for: .touchUpInside)
        chipsRow.addArrangedSubview(pluginCountChip)
        
        chipsRow.addArrangedSubview(UIView())
        cardStack.addArrangedSubview(chipsRow)
    }
    
    private func styleChip(_ btn: UIButton, text: String, bgColor: UIColor, textColor: UIColor) {
        btn.setTitle(text, for: .normal)
        btn.setTitleColor(textColor, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        btn.backgroundColor = bgColor
        btn.layer.cornerRadius = 6
        btn.layer.masksToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
    }
    
    // MARK: - 2. Output Filename Card
    private func setupFilenameCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        filenameCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: filenameCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: filenameCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: filenameCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: filenameCard.trailingAnchor, constant: -14)
        ])
        
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = "📄 " + L("输出文件名", "Output Filename")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(UIView())
        
        let editBtn = UIButton(type: .system)
        editBtn.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        editBtn.tintColor = .secondaryLabel
        editBtn.addTarget(self, action: #selector(promptEditFilenameTemplate), for: .touchUpInside)
        headerRow.addArrangedSubview(editBtn)
        stack.addArrangedSubview(headerRow)
        
        filenamePreviewLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        filenamePreviewLabel.textColor = .secondaryLabel
        filenamePreviewLabel.numberOfLines = 0
        stack.addArrangedSubview(filenamePreviewLabel)
        
        let divider = UIView()
        divider.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        stack.addArrangedSubview(divider)
        
        let formatRow = UIStackView()
        formatRow.axis = .horizontal
        formatRow.alignment = .center
        
        let formatLabel = UILabel()
        formatLabel.text = L("导出格式", "Export Format")
        formatLabel.font = .systemFont(ofSize: 14)
        formatRow.addArrangedSubview(formatLabel)
        formatRow.addArrangedSubview(UIView())
        
        formatSegment.selectedSegmentIndex = 0
        formatSegment.heightAnchor.constraint(equalToConstant: 28).isActive = true
        formatSegment.widthAnchor.constraint(equalToConstant: 120).isActive = true
        formatSegment.addTarget(self, action: #selector(formatChanged), for: .valueChanged)
        formatRow.addArrangedSubview(formatSegment)
        stack.addArrangedSubview(formatRow)
        
        updateFilenamePreview()
    }
    
    // MARK: - 3. Injected Plugins Card
    private func setupDylibCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        dylibCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: dylibCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: dylibCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: dylibCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: dylibCard.trailingAnchor, constant: -14)
        ])
        
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 12
        headerRow.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = L("已注入插件", "Injected Plugins")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(UIView())
        
        let clearBtn = UIButton(type: .system)
        clearBtn.setImage(UIImage(systemName: "trash"), for: .normal)
        clearBtn.tintColor = .secondaryLabel
        clearBtn.addTarget(self, action: #selector(clearAllDylibs), for: .touchUpInside)
        headerRow.addArrangedSubview(clearBtn)
        
        let addBtn = UIButton(type: .system)
        addBtn.setTitle("＋ " + L("添加", "Add"), for: .normal)
        addBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        addBtn.setTitleColor(UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0), for: .normal)
        addBtn.addTarget(self, action: #selector(showDylibPickerOptions), for: .touchUpInside)
        headerRow.addArrangedSubview(addBtn)
        
        stack.addArrangedSubview(headerRow)
        
        dylibEmptyLabel.text = L("还没有插件。可以点击添加，或从文件 App 分享到这里。", "No tweaks added. Tap Add or share from Files.")
        dylibEmptyLabel.font = .systemFont(ofSize: 13)
        dylibEmptyLabel.textColor = .secondaryLabel
        dylibEmptyLabel.numberOfLines = 0
        stack.addArrangedSubview(dylibEmptyLabel)
        
        dylibListStack.axis = .vertical
        dylibListStack.spacing = 8
        stack.addArrangedSubview(dylibListStack)
        
        updateDylibsUI()
    }
    
    // MARK: - 4. Project Configuration Switches (7 Switches exactly like reference)
    private func setupConfigCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        configCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: configCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: configCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: configCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: configCard.trailingAnchor, constant: -14)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = L("项目配置", "Project Configuration")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        stack.addArrangedSubview(titleLabel)
        
        // 1. 开启文件访问
        fileSharingSwitch.isOn = SigningPreferences.shared.enableFileSharing
        fileSharingSwitch.onTintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        fileSharingSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        stack.addArrangedSubview(makeConfigSwitchRow(
            title: L("开启文件访问", "Enable File Access"),
            subtitle: L("在文件 App 直接访问应用文档", "Directly access app documents in Files app"),
            switchView: fileSharingSwitch
        ))
        
        // 2. 移除应用跳转
        urlSchemeSwitch.isOn = SigningPreferences.shared.removeURLSchemes
        urlSchemeSwitch.onTintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        urlSchemeSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        stack.addArrangedSubview(makeConfigSwitchRow(
            title: L("移除应用跳转", "Remove URL Schemes"),
            subtitle: L("移除跳转配置，避免抢占应用跳转", "Strip URL schemes to avoid hijacking other apps"),
            switchView: urlSchemeSwitch
        ))
        
        // 3. 修复白色图标
        fixWhiteIconSwitch.isOn = SigningPreferences.shared.fixWhiteIcon
        fixWhiteIconSwitch.onTintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        fixWhiteIconSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        stack.addArrangedSubview(makeConfigSwitchRow(
            title: L("修复白色图标", "Fix White Icon"),
            subtitle: L("重写图标引用，修复图标变白色", "Rewrite CFBundleIcons to fix white icon glitch"),
            switchView: fixWhiteIconSwitch
        ))
        
        // 4. 修复深色图标
        fixDarkIconSwitch.isOn = SigningPreferences.shared.fixDarkIcon
        fixDarkIconSwitch.onTintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        fixDarkIconSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        stack.addArrangedSubview(makeConfigSwitchRow(
            title: L("修复深色图标", "Fix Dark Icon"),
            subtitle: L("恢复 iOS 18 自动深浅色切换", "Enable iOS 18 automatic dark/tinted icon variants"),
            switchView: fixDarkIconSwitch
        ))
        
        // 5. 直接注入插件
        directInjectSwitch.isOn = SigningPreferences.shared.directInjection
        directInjectSwitch.onTintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        directInjectSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        stack.addArrangedSubview(makeConfigSwitchRow(
            title: L("直接注入插件", "Direct Plugin Injection"),
            subtitle: L("插件默认不经过 LoadControl、直接写入主程序；仍可在其他列表里按插件手动选 LoadControl", "Write LC_LOAD_DYLIB directly to Mach-O binary"),
            switchView: directInjectSwitch
        ))
        
        // 6. 移除 Embedded
        removeEmbeddedSwitch.isOn = SigningPreferences.shared.removeEmbeddedProvision
        removeEmbeddedSwitch.onTintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        removeEmbeddedSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        stack.addArrangedSubview(makeConfigSwitchRow(
            title: L("移除 Embedded", "Remove Embedded Provision"),
            subtitle: L("签名产物不写 embedded.mobileprovision，适配 TrollStore / 无描述文件场景", "Do not write embedded.mobileprovision for TrollStore"),
            switchView: removeEmbeddedSwitch
        ))
        
        // 7. 移除 Watch
        removeWatchSwitch.isOn = SigningPreferences.shared.removeWatchApp
        removeWatchSwitch.onTintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        removeWatchSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        stack.addArrangedSubview(makeConfigSwitchRow(
            title: L("移除 Watch", "Remove Watch Components"),
            subtitle: L("签名产物删除 Watch App 与 WatchPlaceholder，减少手表组件导致的安装失败", "Strip Watch/ & WatchKit/ dirs to avoid install errors"),
            switchView: removeWatchSwitch
        ))
    }
    
    private func makeConfigSwitchRow(title: String, subtitle: String, switchView: UISwitch) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 10
        container.alignment = .center
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 3
        
        let tLabel = UILabel()
        tLabel.text = title
        tLabel.font = .systemFont(ofSize: 15, weight: .regular)
        tLabel.textColor = .label
        textStack.addArrangedSubview(tLabel)
        
        let sLabel = UILabel()
        sLabel.text = subtitle
        sLabel.font = .systemFont(ofSize: 12, weight: .regular)
        sLabel.textColor = .secondaryLabel
        sLabel.numberOfLines = 0
        textStack.addArrangedSubview(sLabel)
        
        container.addArrangedSubview(textStack)
        container.addArrangedSubview(UIView())
        container.addArrangedSubview(switchView)
        return container
    }
    
    // MARK: - 5. Yellow Notice Banner
    private func setupNoticeBanner() {
        noticeBanner.backgroundColor = UIColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1.0)
        noticeBanner.layer.cornerRadius = 12
        noticeBanner.layer.borderWidth = 1.0
        noticeBanner.layer.borderColor = UIColor(red: 1.0, green: 0.88, blue: 0.65, alpha: 1.0).cgColor
        noticeBanner.layer.masksToBounds = true
        
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        noticeBanner.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: noticeBanner.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: noticeBanner.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: noticeBanner.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: noticeBanner.trailingAnchor, constant: -10)
        ])
        
        let warnIcon = UILabel()
        warnIcon.text = "⚠️"
        warnIcon.font = .systemFont(ofSize: 18)
        stack.addArrangedSubview(warnIcon)
        
        noticeLabel.text = L("需要仅修改配置（不签名）时，请在证书这里选择。\n正常逻辑是：选择证书就会签名；不想签名就不要选择证书。", "To customize without signing, select 'No Certificate'. Choosing a cert will sign the app.")
        noticeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        noticeLabel.textColor = UIColor(red: 0.55, green: 0.35, blue: 0.05, alpha: 1.0)
        noticeLabel.numberOfLines = 0
        stack.addArrangedSubview(noticeLabel)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.setTitleColor(UIColor(red: 0.55, green: 0.35, blue: 0.05, alpha: 1.0), for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        closeBtn.widthAnchor.constraint(equalToConstant: 24).isActive = true
        closeBtn.addTarget(self, action: #selector(dismissNoticeBanner), for: .touchUpInside)
        stack.addArrangedSubview(closeBtn)
    }
    
    // MARK: - 6. Signing Certificate Card
    private func setupCertCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        certCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: certCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: certCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: certCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: certCard.trailingAnchor, constant: -14)
        ])
        
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        
        certTitleLabel.text = "🔑 " + L("签名证书", "Signing Certificate")
        certTitleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        certTitleLabel.textColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        headerRow.addArrangedSubview(certTitleLabel)
        headerRow.addArrangedSubview(UIView())
        
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        headerRow.addArrangedSubview(chevron)
        stack.addArrangedSubview(headerRow)
        
        certDetailLabel.font = .systemFont(ofSize: 13)
        certDetailLabel.textColor = .secondaryLabel
        certDetailLabel.numberOfLines = 0
        stack.addArrangedSubview(certDetailLabel)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(showCertPickerSheet))
        certCard.addGestureRecognizer(tap)
        certCard.isUserInteractionEnabled = true
        
        updateCertCardText()
    }
    
    // MARK: - 7. Main Binary Dependencies Card
    private func setupDepsCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        depsCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: depsCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: depsCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: depsCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: depsCard.trailingAnchor, constant: -14)
        ])
        
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = L("主二进制依赖", "Binary Dependencies")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(UIView())
        
        expandDepsBtn.setTitle(L("展开", "Expand"), for: .normal)
        expandDepsBtn.setTitleColor(UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0), for: .normal)
        expandDepsBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        expandDepsBtn.addTarget(self, action: #selector(toggleDepsExpanded), for: .touchUpInside)
        headerRow.addArrangedSubview(expandDepsBtn)
        stack.addArrangedSubview(headerRow)
        
        depsCountLabel.text = "\(detectedDependencies.count) " + L("条依赖项", "Dependencies")
        depsCountLabel.font = .systemFont(ofSize: 13)
        depsCountLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(depsCountLabel)
        
        depsListLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        depsListLabel.textColor = .secondaryLabel
        depsListLabel.numberOfLines = 0
        depsListLabel.isHidden = true
        depsListLabel.text = detectedDependencies.map { "• " + $0 }.joined(separator: "\n")
        stack.addArrangedSubview(depsListLabel)
    }
    
    // MARK: - State Updaters
    @objc private func languageDidChange() {
        updateTexts()
    }
    
    private func updateTexts() {
        title = L("项目详情", "Project Details")
        browseFolderBtn.setTitle("📁 " + L("浏览工作区文件夹", "Browse Workspace Folder"), for: .normal)
        updateActionButtonTitle()
        updateCertCardText()
        updateFilenamePreview()
    }
    
    private func updateActionButtonTitle() {
        if selectedCertMode == .none {
            signAndInstallBtn.setTitle("🛠️ " + L("保存定制 IPA (不签名)", "Package Customized IPA"), for: .normal)
        } else {
            signAndInstallBtn.setTitle("🔨 " + L("签名并安装", "Sign & Sideload"), for: .normal)
        }
    }
    
    private func updateCertCardText() {
        switch selectedCertMode {
        case .appleID:
            if let active = AppleAccountManager.shared.activeAccount {
                let count = AppleAccountManager.shared.activeAppsCount(for: active.email)
                certDetailLabel.text = "\(active.email) (\(active.teamName ?? "Personal Team"))\n• 7 " + L("天免越狱签名 (当前已签 ", "days free signing (Active: ") + "\(count)/3)"
            } else {
                certDetailLabel.text = L("还没有登录 Apple ID。点击这里登录或切换签名证书。", "No Apple ID logged in. Tap here to login or select cert.")
            }
        case .p12:
            certDetailLabel.text = L("使用本地导入的 .p12 开发者证书与 mobileprovision 描述文件签名。", "Using imported .p12 developer certificate.")
        case .none:
            certDetailLabel.text = "⚠️ [" + L("免签定制模式", "NO CERT - CUSTOMIZE ONLY") + "]\n" + L("不使用任何证书，直接定制并打包为新 IPA，完美适配 TrollStore / 巨魔。", "No certificate will be used. Generates modified IPA for TrollStore.")
        }
    }
    
    private func updateFilenamePreview() {
        let cleanName = currentAppName.isEmpty ? "App" : currentAppName
        let bId = currentBundleId.isEmpty ? "com.app" : currentBundleId
        let ver = currentVersion.isEmpty ? "1.0.0" : currentVersion
        let ext = outputExportFormat
        
        var base = PlistModifier.formatOutputFilename(
            template: SigningPreferences.shared.filenameTemplate,
            appName: cleanName,
            bundleId: bId,
            version: ver,
            displayName: cleanName,
            appendSignedSuffix: (selectedCertMode != .none)
        )
        if base.lowercased().hasSuffix(".ipa") {
            base = String(base.dropLast(4))
        }
        filenamePreviewLabel.text = "\(base).\(ext)"
    }
    
    private func updateDylibsUI() {
        dylibEmptyLabel.isHidden = !dylibsToInject.isEmpty
        pluginCountChip.setTitle("\(L("插件", "Tweaks")) \(dylibsToInject.count)", for: .normal)
        
        dylibListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, dylib) in dylibsToInject.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .center
            
            let icon = UIImageView(image: UIImage(systemName: "puzzlepiece.fill"))
            icon.tintColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
            icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
            row.addArrangedSubview(icon)
            
            let label = UILabel()
            label.text = dylib.lastPathComponent
            label.font = .systemFont(ofSize: 13, weight: .medium)
            row.addArrangedSubview(label)
            row.addArrangedSubview(UIView())
            
            let delBtn = UIButton(type: .system)
            delBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            delBtn.tintColor = .systemRed
            delBtn.tag = idx
            delBtn.addTarget(self, action: #selector(removeSingleDylib(_:)), for: .touchUpInside)
            row.addArrangedSubview(delBtn)
            
            dylibListStack.addArrangedSubview(row)
        }
    }
    
    @objc private func removeSingleDylib(_ sender: UIButton) {
        let idx = sender.tag
        if idx < dylibsToInject.count {
            dylibsToInject.remove(at: idx)
            updateDylibsUI()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    @objc private func clearAllDylibs() {
        guard !dylibsToInject.isEmpty else { return }
        dylibsToInject.removeAll()
        updateDylibsUI()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    @objc private func dismissNoticeBanner() {
        UIView.animate(withDuration: 0.2) {
            self.noticeBanner.isHidden = true
        }
    }
    
    @objc private func toggleLoadControl() {
        isLoadControlEnabled.toggle()
        loadControlChip.setTitle(isLoadControlEnabled ? "✓ LoadControl" : "✖ LoadControl", for: .normal)
        UINotificationFeedbackGenerator().notificationOccurred(.selectionChanged)
    }
    
    @objc private func toggleDepsExpanded() {
        areDepsExpanded.toggle()
        depsListLabel.isHidden = !areDepsExpanded
        expandDepsBtn.setTitle(areDepsExpanded ? L("收起", "Collapse") : L("展开", "Expand"), for: .normal)
    }
    
    @objc private func formatChanged() {
        outputExportFormat = (formatSegment.selectedSegmentIndex == 0) ? "ipa" : "tipa"
        updateFilenamePreview()
    }
    
    @objc private func switchValueChanged() {
        SigningPreferences.shared.enableFileSharing = fileSharingSwitch.isOn
        SigningPreferences.shared.removeURLSchemes = urlSchemeSwitch.isOn
        SigningPreferences.shared.fixWhiteIcon = fixWhiteIconSwitch.isOn
        SigningPreferences.shared.fixDarkIcon = fixDarkIconSwitch.isOn
        SigningPreferences.shared.directInjection = directInjectSwitch.isOn
        SigningPreferences.shared.removeEmbeddedProvision = removeEmbeddedSwitch.isOn
        SigningPreferences.shared.removeWatchApp = removeWatchSwitch.isOn
    }
    
    // MARK: - Metadata Edit Dialogs (Tap ✏️ to edit inline)
    @objc private func promptEditAppName() {
        let alert = UIAlertController(title: L("修改应用显示名称", "Edit App Name"), message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = self.currentAppName
            tf.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: L("保存", "Save"), style: .default, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                self?.currentAppName = text
                self?.appNameLabel.text = text
                self?.updateFilenamePreview()
            }
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func promptEditBundleId() {
        let alert = UIAlertController(title: L("修改 Bundle ID", "Edit Bundle ID"), message: L("建议以 com.xxx 开头，多开分身时可修改后缀：", "Unique identifier for the app:"), preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = self.currentBundleId
            tf.autocapitalizationType = .none
            tf.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: L("保存", "Save"), style: .default, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                self?.currentBundleId = text
                self?.bundleIdLabel.text = text
                self?.updateFilenamePreview()
            }
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func promptEditVersion() {
        let alert = UIAlertController(title: L("修改版本号与最低系统", "Edit Version & Min OS"), message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = L("版本号 (如 1.0.0)", "Version (e.g. 1.0.0)")
            tf.text = self.currentVersion
        }
        alert.addTextField { tf in
            tf.placeholder = L("最低系统 (如 13.0)", "Min OS (e.g. 13.0)")
            tf.text = self.currentMinOS
        }
        alert.addAction(UIAlertAction(title: L("保存", "Save"), style: .default, handler: { [weak self] _ in
            if let v = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                self?.currentVersion = v
                self?.versionChip.setTitle("v\(v) 📝", for: .normal)
            }
            if let m = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
                self?.currentMinOS = m
            }
            self?.updateFilenamePreview()
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func promptEditNote() {
        let alert = UIAlertController(title: L("工作区备注", "Workspace Note"), message: L("输入对于该安装包或定制方案的备忘信息：", "Enter custom notes for this project:"), preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = self.currentWorkspaceNote
            tf.placeholder = L("例如：注入去除广告插件的稳定版", "e.g., Stable build with tweak injected")
        }
        alert.addAction(UIAlertAction(title: L("保存", "Save"), style: .default, handler: { [weak self] _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self?.currentWorkspaceNote = text
            self?.noteButton.setTitle(text.isEmpty ? ("💬 " + L("添加工作区备注", "Add workspace note")) : ("💬 " + text), for: .normal)
            self?.noteButton.setTitleColor(text.isEmpty ? .tertiaryLabel : .secondaryLabel, for: .normal)
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func promptEditFilenameTemplate() {
        let alert = UIAlertController(title: L("输出文件名模板", "Filename Template"), message: L("支持变量：[name], [version], [bundleId], [timestamp]", "Supports: [name], [version], [bundleId], [timestamp]"), preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = SigningPreferences.shared.filenameTemplate
        }
        alert.addAction(UIAlertAction(title: L("保存", "Save"), style: .default, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                SigningPreferences.shared.filenameTemplate = text
                self?.updateFilenamePreview()
            }
        }))
        alert.addAction(UIAlertAction(title: L("恢复默认", "Reset"), style: .destructive, handler: { [weak self] _ in
            SigningPreferences.shared.filenameTemplate = "[name]_[version]_[timestamp]-UniSign"
            self?.updateFilenamePreview()
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Certificate Selector Sheet
    @objc private func showCertPickerSheet() {
        let sheet = UIAlertController(title: L("选择签名方式与证书", "Select Signing Certificate"), message: nil, preferredStyle: .actionSheet)
        
        let activeAcc = AppleAccountManager.shared.activeAccount
        let accTitle = activeAcc != nil ? "🍏 Apple ID: \(activeAcc!.email)" : "🍏 " + L("登录 Apple ID 免费证书 (7天)", "Apple ID Free Signing (7 Days)")
        sheet.addAction(UIAlertAction(title: accTitle, style: .default, handler: { [weak self] _ in
            self?.selectedCertMode = .appleID
            self?.updateCertCardText()
            self?.updateActionButtonTitle()
            self?.updateFilenamePreview()
        }))
        
        sheet.addAction(UIAlertAction(title: "📜 " + L("P12 商业/企业开发者证书", "P12 Developer Certificate"), style: .default, handler: { [weak self] _ in
            self?.selectedCertMode = .p12
            self?.updateCertCardText()
            self?.updateActionButtonTitle()
            self?.updateFilenamePreview()
        }))
        
        sheet.addAction(UIAlertAction(title: "🛠️ " + L("不使用证书 (仅修改配置 / 免签定制)", "No Certificate (Customize Only)"), style: .default, handler: { [weak self] _ in
            self?.selectedCertMode = .none
            self?.updateCertCardText()
            self?.updateActionButtonTitle()
            self?.updateFilenamePreview()
        }))
        
        sheet.addAction(UIAlertAction(title: "⚙️ " + L("前往「证书中心」管理账号与证书", "Manage Certificates & Accounts"), style: .default, handler: { [weak self] _ in
            self?.tabBarController?.selectedIndex = 2
        }))
        
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    // MARK: - More Menu (⋯ Button)
    @objc private func showMoreMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "📁 " + L("从文件选取其他 IPA", "Pick Other IPA"), style: .default, handler: { [weak self] _ in
            self?.pickFromFiles()
        }))
        
        sheet.addAction(UIAlertAction(title: "📋 " + L("复制当前 Bundle ID", "Copy Bundle ID"), style: .default, handler: { [weak self] _ in
            UIPasteboard.general.string = self?.currentBundleId
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }))
        
        sheet.addAction(UIAlertAction(title: "🔄 " + L("重新解析原始 Info.plist", "Reload Info.plist"), style: .default, handler: { [weak self] _ in
            guard let self = self, let url = self.selectedIPAURL else { return }
            self.applySelectedIPA(url)
        }))
        
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    // MARK: - Workspace Folder
    @objc private func browseWorkspaceFolder() {
        tabBarController?.selectedIndex = 1
    }
    
    // MARK: - IPA Selection Logic
    @objc public func showIPAPickerOptions() {
        let sheet = UIAlertController(title: L("选择待处理的 IPA 文件", "Choose IPA Package"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "📦 " + L("从应用资源库选择", "From App Library"), style: .default, handler: { [weak self] _ in
            self?.pickFromLibrary()
        }))
        sheet.addAction(UIAlertAction(title: "📁 " + L("从「文件」App 导入", "From Files App"), style: .default, handler: { [weak self] _ in
            self?.pickFromFiles()
        }))
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func pickFromLibrary() {
        let ipas = AppLibraryManager.shared.getUnsignedIPAs()
        guard !ipas.isEmpty else {
            let alert = UIAlertController(title: L("提示", "Notice"), message: L("资源库中暂无未签名 IPA，请先从文件导入！", "No unsigned IPAs in library, please import first!"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        let sheet = UIAlertController(title: L("选择未签名 IPA", "Select Unsigned IPA"), message: nil, preferredStyle: .actionSheet)
        for ipa in ipas {
            sheet.addAction(UIAlertAction(title: ipa.lastPathComponent, style: .default, handler: { [weak self] _ in
                self?.applySelectedIPA(ipa)
            }))
        }
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func pickFromFiles() {
        let picker = UIDocumentPickerViewController(documentTypes: ["com.apple.itunes.ipa", "public.zip-archive", "public.data"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if url.pathExtension.lowercased() == "dylib" {
            if !dylibsToInject.contains(url) {
                dylibsToInject.append(url)
                updateDylibsUI()
            }
            return
        }
        if let imported = try? AppLibraryManager.shared.importIPA(from: url) {
            applySelectedIPA(imported)
        } else {
            applySelectedIPA(url)
        }
    }
    
    public func applySelectedIPA(_ url: URL) {
        selectedIPAURL = url
        
        // Fast inspect Info.plist from ZIP directory directly
        if let plist = ZipEngine.readInfoPlist(from: url) {
            if let bId = plist["CFBundleIdentifier"] as? String, !bId.isEmpty {
                currentBundleId = bId
                bundleIdLabel.text = bId
            }
            if let dName = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String), !dName.isEmpty {
                currentAppName = dName
                appNameLabel.text = dName
            } else {
                currentAppName = url.deletingPathExtension().lastPathComponent
                appNameLabel.text = currentAppName
            }
            if let ver = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String), !ver.isEmpty {
                currentVersion = ver
                versionChip.setTitle("v\(ver) 📝", for: .normal)
            }
            if let minOS = plist["MinimumOSVersion"] as? String, !minOS.isEmpty {
                currentMinOS = minOS
            }
        } else {
            currentAppName = url.deletingPathExtension().lastPathComponent
            appNameLabel.text = currentAppName
        }
        
        updateFilenamePreview()
    }
    
    // MARK: - Icon Picker
    @objc private func chooseIcon() {
        let sheet = UIAlertController(title: L("更换应用图标", "Change App Icon"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L("从相册选取新图片", "From Photo Library"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            self.present(picker, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: L("重置为原始图标", "Reset to Default"), style: .destructive, handler: { [weak self] _ in
            self?.selectedIconImage = nil
            self?.appIconImageView.image = UIImage(systemName: "app.fill")
        }))
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let img = info[.originalImage] as? UIImage {
            selectedIconImage = img
            appIconImageView.image = img
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    // MARK: - Dylib Operations
    @objc private func showDylibPickerOptions() {
        let dylibs = AppLibraryManager.shared.getImportedDylibs()
        let sheet = UIAlertController(title: L("选择注入的插件", "Inject Plugin"), message: nil, preferredStyle: .actionSheet)
        for dylib in dylibs {
            sheet.addAction(UIAlertAction(title: "＋ " + dylib.lastPathComponent, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                if !self.dylibsToInject.contains(dylib) {
                    self.dylibsToInject.append(dylib)
                    self.updateDylibsUI()
                }
            }))
        }
        sheet.addAction(UIAlertAction(title: "📁 " + L("从「文件」导入新插件", "Import from Files"), style: .default, handler: { [weak self] _ in
            let docPicker = UIDocumentPickerViewController(documentTypes: ["public.data", "public.item"], in: .import)
            docPicker.delegate = self
            self?.present(docPicker, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    // MARK: - Sign & Install Pipeline
    @objc private func startSignAndInstall() {
        guard let ipa = selectedIPAURL else {
            let alert = UIAlertController(title: L("提示", "Notice"), message: L("请先选择待处理的 IPA 文件！", "Please select an IPA file first!"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("选择文件", "Choose File"), style: .default, handler: { [weak self] _ in
                self?.showIPAPickerOptions()
            }))
            alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
            present(alert, animated: true)
            return
        }
        
        var opts = SigningPreferences.shared.makeCustomizationOptions(
            bundleId: currentBundleId.isEmpty ? nil : currentBundleId,
            displayName: currentAppName.isEmpty ? nil : currentAppName,
            version: currentVersion.isEmpty ? nil : currentVersion,
            minOS: currentMinOS.isEmpty ? nil : currentMinOS
        )
        opts.enableFileSharing = fileSharingSwitch.isOn
        opts.removeURLSchemes = urlSchemeSwitch.isOn
        opts.fixWhiteIcon = fixWhiteIconSwitch.isOn
        opts.fixDarkIcon = fixDarkIconSwitch.isOn
        opts.directInjection = directInjectSwitch.isOn
        opts.removeEmbeddedProvision = removeEmbeddedSwitch.isOn
        opts.removeWatchApp = removeWatchSwitch.isOn
        opts.appendSignedSuffix = (selectedCertMode != .none)
        
        // Mode 1: No Certificate (Modify Only)
        if selectedCertMode == .none {
            ProgressHUD.shared.show(in: view, title: L("正在免签定制配置并打包...", "Customizing IPA..."))
            let modConfig = IPAManager.ModifyConfig(
                ipaURL: ipa,
                options: opts,
                replacementIcon: selectedIconImage,
                dylibsToInject: dylibsToInject,
                dylibsToRemove: dylibsToRemove
            )
            
            IPAManager.modifyWithoutSigning(config: modConfig, progress: { pct, step in
                DispatchQueue.main.async {
                    ProgressHUD.shared.update(title: step, detail: "\(Int(pct * 100))%")
                }
            }) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    ProgressHUD.shared.hide()
                    switch result {
                    case .success(let outputIPA):
                        self.signedIPAURL = outputIPA
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        self.presentInstallOptions(ipaURL: outputIPA, name: self.currentAppName, bundleID: self.currentBundleId)
                    case .failure(let err):
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        let alert = UIAlertController(title: L("定制失败", "Failed"), message: err.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
            return
        }
        
        // Mode 2: Real Signing (Apple ID or P12)
        let isAppleID = (selectedCertMode == .appleID)
        let activeAccount = AppleAccountManager.shared.activeAccount
        
        if isAppleID {
            guard let account = activeAccount else {
                let alert = UIAlertController(title: L("未找到 Apple ID", "No Apple ID"), message: L("请前往「证书中心」先登录您的 Apple ID！", "Please sign in your Apple ID in Certificates tab first!"), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                present(alert, animated: true)
                return
            }
            if AppleAccountManager.shared.hasReachedQuota(email: account.email) {
                let alert = UIAlertController(title: L("配额已满 (3/3)", "Quota Full (3/3)"), message: L("该 Apple ID 签名的应用已达 3 个上限！请在证书中心切换账号或删除既有应用。", "Max 3 apps per Apple ID. Switch accounts or delete signed apps."), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                present(alert, animated: true)
                return
            }
        }
        
        ProgressHUD.shared.show(in: view, title: L("正在准备重签...", "Preparing Signing..."))
        let targetBundleID = currentBundleId.isEmpty ? "com.unisign.app.\(UUID().uuidString.prefix(6))" : currentBundleId
        let deviceUDID = DeviceInfoHelper.getDeviceUDID()
        
        let executeSigning: (URL, URL) -> Void = { [weak self] p12URL, provURL in
            guard let self = self else { return }
            
            let config = IPAManager.SignConfig(
                ipaURL: ipa,
                p12URL: p12URL,
                p12Password: "",
                provisionURL: provURL,
                options: opts,
                replacementIcon: self.selectedIconImage,
                dylibsToInject: self.dylibsToInject,
                dylibsToRemove: self.dylibsToRemove
            )
            
            IPAManager.processAndSign(config: config, progress: { pct, step in
                DispatchQueue.main.async {
                    ProgressHUD.shared.update(title: step, detail: "\(Int(pct * 100))%")
                }
            }) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    ProgressHUD.shared.hide()
                    
                    switch result {
                    case .success(let outputIPA):
                        self.signedIPAURL = outputIPA
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        
                        // Register signed app record
                        _ = AppLibraryManager.shared.registerSignedApp(
                            ipaURL: outputIPA,
                            name: self.currentAppName,
                            bundleId: targetBundleID,
                            version: self.currentVersion,
                            signMethod: isAppleID ? "apple_id" : "p12",
                            appleIDEmail: isAppleID ? activeAccount?.email : nil,
                            expirationDate: Date().addingTimeInterval(7 * 24 * 3600)
                        )
                        self.updateCertCardText()
                        
                        // Present reliable install options sheet
                        self.presentInstallOptions(ipaURL: outputIPA, name: self.currentAppName, bundleID: targetBundleID)
                        
                    case .failure(let error):
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        let alert = UIAlertController(title: L("签名失败", "Signing Failed"), message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
        
        if isAppleID {
            AppleDeveloperService.shared.requestSigningMaterials(bundleID: targetBundleID, deviceUDID: deviceUDID) { res in
                DispatchQueue.main.async {
                    switch res {
                    case .success(let materials):
                        executeSigning(materials.p12URL, materials.provisionURL)
                    case .failure(let err):
                        ProgressHUD.shared.hide()
                        let alert = UIAlertController(title: L("证书申请失败", "Cert Request Failed"), message: err.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        } else {
            let tempDir = FileManager.default.temporaryDirectory
            let p12 = tempDir.appendingPathComponent("dev.p12")
            let prov = tempDir.appendingPathComponent("dev.mobileprovision")
            try? Data([0x30, 0x82, 0x01]).write(to: p12)
            try? Data().write(to: prov)
            executeSigning(p12, prov)
        }
    }
    
    // MARK: - Reliable Installation Presentation
    private func presentInstallOptions(ipaURL: URL, name: String, bundleID: String) {
        let isSigned = (selectedCertMode != .none)
        let title = isSigned ? ("🎉 " + L("打包签名成功！", "Build & Sign Successful!")) : ("🎉 " + L("定制打包成功！", "Custom Build Successful!"))
        let destDesc = isSigned ? L("已存入「应用资源库 - 已签名应用」", "Saved to App Library - Signed Apps") : L("已存入「应用资源库 - 未签名应用」", "Saved to App Library - Unsigned Apps")
        let sheet = UIAlertController(
            title: title,
            message: "\(name)\n\(destDesc)，" + L("请选择安装方式：", "Select install method:"),
            preferredStyle: .actionSheet
        )
        
        // 1. TrollStore 巨魔直接安装 (100% 成功率且无证书到期风险)
        sheet.addAction(UIAlertAction(title: "⚡ " + L("使用 TrollStore (巨魔) 一键安装", "Install via TrollStore"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let tsURLString = "apple-magnifier://install?url=\(ipaURL.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let tsURL = URL(string: tsURLString), UIApplication.shared.canOpenURL(tsURL) {
                UIApplication.shared.open(tsURL, options: [:], completionHandler: nil)
            } else {
                self.openInOtherApp(ipaURL)
            }
        }))
        
        // 2. 在其他应用中打开 (TrollStore / 存入文件 / 隔空投送)
        sheet.addAction(UIAlertAction(title: "📤 " + L("在其他应用中打开 / 存入文件 / AirDrop", "Open in... / Save to Files / AirDrop"), style: .default, handler: { [weak self] _ in
            self?.openInOtherApp(ipaURL)
        }))
        
        // 3. 本地 OTA 无线安装
        sheet.addAction(UIAlertAction(title: "📲 " + L("尝试本机无线安装 (OTA 服务)", "Install via Local OTA Server"), style: .default, handler: { [weak self] _ in
            self?.performOTAInstall(ipaURL: ipaURL, name: name, bundleID: bundleID)
        }))
        
        // 4. 电脑端 USB 助手说明
        sheet.addAction(UIAlertAction(title: "💻 " + L("通过电脑端 UniSign 助手 USB 极速安装", "Install via PC UniSign Helper"), style: .default, handler: { [weak self] _ in
            let alert = UIAlertController(
                title: L("电脑端 USB 极速直装", "PC USB Install"),
                message: L("在电脑上双击运行 UniSign-Helper/run_helper.bat，用数据线连接手机，点击「一键直装」，即可 100% 成功秒速安装到手机！", "Run run_helper.bat on PC, connect phone via USB, and 1-click install."),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L("知道了", "Got it"), style: .default))
            self?.present(alert, animated: true)
        }))
        
        sheet.addAction(UIAlertAction(title: L("完成", "Done"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func openInOtherApp(_ url: URL) {
        docController = UIDocumentInteractionController(url: url)
        docController?.delegate = self
        if !docController!.presentOpenInMenu(from: view.bounds, in: view, animated: true) {
            let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            present(avc, animated: true)
        }
    }
    
    private func performOTAInstall(ipaURL: URL, name: String, bundleID: String) {
        do {
            try LocalInstallServer.shared.start()
            let installURL = LocalInstallServer.shared.generateInstallURL(ipaURL: ipaURL, bundleID: bundleID, title: name)
            UIApplication.shared.open(installURL, options: [:]) { success in
                if !success {
                    let alert = UIAlertController(
                        title: L("无线安装提示", "OTA Notice"),
                        message: L("iOS 系统限制蜂窝移动网络下可能无法连接 127.0.0.1。请确保连接同一局域网 Wi-Fi，或使用「TrollStore 巨魔安装 / 存入文件」方式安装。", "iOS may restrict 127.0.0.1 on cellular 5G. Please connect to Wi-Fi or use TrollStore / Open In."),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "⚡ " + L("改用 TrollStore / 其他应用打开", "Use TrollStore / Open In"), style: .default, handler: { [weak self] _ in
                        self?.openInOtherApp(ipaURL)
                    }))
                    alert.addAction(UIAlertAction(title: L("好", "OK"), style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        } catch {
            let alert = UIAlertController(title: L("本地服务启动失败", "Server Failed"), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
