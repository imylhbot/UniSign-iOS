import UIKit

public class SignWorkflowViewController: UIViewController, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    // Selected files
    public var preselectedIPAURL: URL?
    private var selectedIPAURL: URL?
    private var selectedP12URL: URL?
    private var selectedProvisionURL: URL?
    private var selectedIconImage: UIImage?
    private var dylibsToInject: [URL] = []
    private var dylibsToRemove: [String] = []
    
    // Cards
    private let ipaCard = CardView()
    private let ipaButton = GradientButton(title: "", style: .primaryCyber, icon: UIImage(systemName: "shippingbox.fill"))
    private let ipaDetailLabel = UILabel()
    
    private let methodCard = CardView()
    private let signingMethodSegment = UISegmentedControl(items: [
        L("Apple ID 免越狱", "Apple ID"),
        L("P12 商业证书", "P12 Certificate")
    ])
    private let accountQuotaBadge = PillBadge(text: "", style: .info)
    private let methodDetailLabel = UILabel()
    
    private let customCard = CardView()
    private let bundleIdField = UITextField()
    private let nameField = UITextField()
    private let versionField = UITextField()
    private let minOSField = UITextField()
    private let fileSharingSwitch = UISwitch()
    private let docInPlaceSwitch = UISwitch()
    
    private let iconCard = CardView()
    private let iconPreview = UIImageView()
    private let changeIconButton = GradientButton(title: "", style: .secondaryGray, icon: UIImage(systemName: "photo.badge.plus"))
    
    private let dylibCard = CardView()
    private let dylibLabel = UILabel()
    private let addDylibBtn = GradientButton(title: "", style: .primaryCyber, icon: UIImage(systemName: "plus"))
    private let removeDylibBtn = GradientButton(title: "", style: .destructive, icon: UIImage(systemName: "trash"))
    
    // Actions
    private let signButton = GradientButton(title: "", style: .primaryCyber, icon: UIImage(systemName: "signature"))
    private let installButton = GradientButton(title: "", style: .appleBrand, icon: UIImage(systemName: "arrow.down.app.fill"))
    
    private var signedIPAURL: URL?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupUI()
        updateTexts()
        
        if let preselected = preselectedIPAURL {
            applySelectedIPA(preselected)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAccountQuotaBadge()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 16
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 12),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -30),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // 1. Source IPA Card
        setupIPACard()
        contentView.addArrangedSubview(ipaCard)
        
        // 2. Signing Method Card
        setupMethodCard()
        contentView.addArrangedSubview(methodCard)
        
        // 3. Metadata Customization Card
        setupCustomCard()
        contentView.addArrangedSubview(customCard)
        
        // 4. Icon Card
        setupIconCard()
        contentView.addArrangedSubview(iconCard)
        
        // 5. Dylib Card
        setupDylibCard()
        contentView.addArrangedSubview(dylibCard)
        
        // 6. Action Buttons
        signButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        signButton.addTarget(self, action: #selector(startSigning), for: .touchUpInside)
        contentView.addArrangedSubview(signButton)
        
        installButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        installButton.isHidden = true
        installButton.addTarget(self, action: #selector(installAppLocally), for: .touchUpInside)
        contentView.addArrangedSubview(installButton)
    }
    
    private func setupIPACard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        ipaCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: ipaCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: ipaCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: ipaCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: ipaCard.trailingAnchor, constant: -14)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = L("1. 选择待签名 IPA 包", "1. Source IPA File")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        stack.addArrangedSubview(titleLabel)
        
        ipaButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        ipaButton.addTarget(self, action: #selector(showIPAPickerOptions), for: .touchUpInside)
        stack.addArrangedSubview(ipaButton)
        
        ipaDetailLabel.font = .systemFont(ofSize: 12)
        ipaDetailLabel.textColor = .secondaryLabel
        ipaDetailLabel.text = L("尚未选择任何 IPA 文件", "No IPA selected")
        stack.addArrangedSubview(ipaDetailLabel)
    }
    
    private func setupMethodCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        methodCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: methodCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: methodCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: methodCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: methodCard.trailingAnchor, constant: -14)
        ])
        
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = L("2. 选择签名证书与身份", "2. Signing Identity")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(accountQuotaBadge)
        stack.addArrangedSubview(headerRow)
        
        signingMethodSegment.selectedSegmentIndex = 0
        signingMethodSegment.heightAnchor.constraint(equalToConstant: 34).isActive = true
        signingMethodSegment.addTarget(self, action: #selector(methodChanged), for: .valueChanged)
        stack.addArrangedSubview(signingMethodSegment)
        
        methodDetailLabel.font = .systemFont(ofSize: 12)
        methodDetailLabel.textColor = .secondaryLabel
        methodDetailLabel.numberOfLines = 0
        stack.addArrangedSubview(methodDetailLabel)
        
        updateAccountQuotaBadge()
    }
    
    private func setupCustomCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        customCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: customCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: customCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: customCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: customCard.trailingAnchor, constant: -14)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = L("3. 深度定制与权限开关", "3. Modifications & Permissions")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        stack.addArrangedSubview(titleLabel)
        
        bundleIdField.borderStyle = .roundedRect
        bundleIdField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        bundleIdField.autocapitalizationType = .none
        stack.addArrangedSubview(bundleIdField)
        
        nameField.borderStyle = .roundedRect
        nameField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stack.addArrangedSubview(nameField)
        
        let versionStack = UIStackView()
        versionStack.axis = .horizontal
        versionStack.spacing = 10
        versionStack.distribution = .fillEqually
        versionField.borderStyle = .roundedRect
        versionField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        minOSField.borderStyle = .roundedRect
        minOSField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        versionStack.addArrangedSubview(versionField)
        versionStack.addArrangedSubview(minOSField)
        stack.addArrangedSubview(versionStack)
        
        let switch1 = makeSwitchRow(title: L("开启文件共享 (UIFileSharingEnabled)", "Enable File Sharing (UIFileSharing)"), switchView: fileSharingSwitch)
        let switch2 = makeSwitchRow(title: L("支持文件 App 原地打开 (LSSupportsOpening)", "Open In Place (LSSupportsOpening)"), switchView: docInPlaceSwitch)
        fileSharingSwitch.isOn = true
        docInPlaceSwitch.isOn = true
        stack.addArrangedSubview(switch1)
        stack.addArrangedSubview(switch2)
    }
    
    private func setupIconCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        iconCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: iconCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: iconCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: iconCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: iconCard.trailingAnchor, constant: -14)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = L("4. 应用图标替换 (可选)", "4. App Icon Replacement")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        stack.addArrangedSubview(titleLabel)
        
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        
        iconPreview.backgroundColor = UIColor.label.withAlphaComponent(0.06)
        iconPreview.layer.cornerRadius = 14
        iconPreview.layer.masksToBounds = true
        iconPreview.contentMode = .scaleAspectFill
        iconPreview.image = UIImage(systemName: "app.fill")
        iconPreview.tintColor = .systemBlue
        iconPreview.widthAnchor.constraint(equalToConstant: 58).isActive = true
        iconPreview.heightAnchor.constraint(equalToConstant: 58).isActive = true
        row.addArrangedSubview(iconPreview)
        
        changeIconButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        changeIconButton.addTarget(self, action: #selector(chooseIcon), for: .touchUpInside)
        row.addArrangedSubview(changeIconButton)
        stack.addArrangedSubview(row)
    }
    
    private func setupDylibCard() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        dylibCard.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: dylibCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: dylibCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: dylibCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: dylibCard.trailingAnchor, constant: -14)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = L("5. 注入 / 移除 Mach-O 插件", "5. Dynamic Library Injection")
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        stack.addArrangedSubview(titleLabel)
        
        dylibLabel.font = .systemFont(ofSize: 12)
        dylibLabel.textColor = .secondaryLabel
        dylibLabel.numberOfLines = 0
        stack.addArrangedSubview(dylibLabel)
        
        let btnStack = UIStackView()
        btnStack.axis = .horizontal
        btnStack.spacing = 10
        btnStack.distribution = .fillEqually
        
        addDylibBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        addDylibBtn.addTarget(self, action: #selector(showDylibPickerOptions), for: .touchUpInside)
        btnStack.addArrangedSubview(addDylibBtn)
        
        removeDylibBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        removeDylibBtn.addTarget(self, action: #selector(promptRemoveDylib), for: .touchUpInside)
        btnStack.addArrangedSubview(removeDylibBtn)
        
        stack.addArrangedSubview(btnStack)
    }
    
    private func makeSwitchRow(title: String, switchView: UISwitch) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 1
        
        row.addArrangedSubview(label)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(switchView)
        return row
    }
    
    @objc private func languageDidChange() {
        updateTexts()
    }
    
    private func updateTexts() {
        title = L("签名与深度定制", "Sign & Customize")
        ipaButton.setTitle(L("选取待签名 IPA 包", "Choose IPA Package"), for: .normal)
        changeIconButton.setTitle(L("选取新图标 (相册/文件)", "Change Icon"), for: .normal)
        bundleIdField.placeholder = L("自定义 Bundle ID (留空保持原样)", "Custom Bundle ID")
        nameField.placeholder = L("自定义应用显示名称 (留空保持原样)", "Custom App Name")
        versionField.placeholder = L("版本号 (如 1.0.0)", "Version (e.g. 1.0.0)")
        minOSField.placeholder = L("最低系统 (如 13.0)", "Min OS (e.g. 13.0)")
        addDylibBtn.setTitle(L("选择注入插件", "Add Dylib"), for: .normal)
        removeDylibBtn.setTitle(L("移除既有插件", "Remove Dylib"), for: .normal)
        signButton.setTitle(L("🚀 开始一键重签与注入", "🚀 Start Signing IPA"), for: .normal)
        installButton.setTitle(L("📲 立即本地安装 (OTA)", "📲 Install Locally (OTA)"), for: .normal)
        updateDylibLabel()
        updateMethodDetailText()
    }
    
    @objc private func methodChanged() {
        updateAccountQuotaBadge()
        updateMethodDetailText()
    }
    
    private func updateAccountQuotaBadge() {
        if signingMethodSegment.selectedSegmentIndex == 0 {
            if let active = AppleAccountManager.shared.activeAccount {
                let count = AppleAccountManager.shared.activeAppsCount(for: active.email)
                if count >= 3 {
                    accountQuotaBadge.update(text: "\(active.email) (3/3 满额)", style: .danger)
                } else {
                    accountQuotaBadge.update(text: "\(active.email) (\(count)/3)", style: .success)
                }
            } else {
                accountQuotaBadge.update(text: L("未登录 Apple ID", "No Apple ID"), style: .warning)
            }
        } else {
            accountQuotaBadge.update(text: L("P12 商业签名", "P12 Mode"), style: .info)
        }
    }
    
    private func updateMethodDetailText() {
        if signingMethodSegment.selectedSegmentIndex == 0 {
            if let active = AppleAccountManager.shared.activeAccount {
                methodDetailLabel.text = "\(L("使用账号", "Account")): \(active.email) (\(active.teamName ?? "Personal Team"))\n\(L("说明", "Notice")): 7 " + L("天免越狱签名，每账号限制最多签名 3 个应用", "days validity, max 3 apps per account.")
            } else {
                methodDetailLabel.text = L("⚠️ 尚未登录 Apple ID，请先在「证书中心」添加您的个人 Apple 账号。", "⚠️ No Apple ID logged in. Please add an account in Certificates tab.")
            }
        } else {
            methodDetailLabel.text = L("使用预先导入的 .p12 开发者证书与 mobileprovision 描述文件重签。", "Sign using imported .p12 cert and mobileprovision profile.")
        }
    }
    
    private func updateDylibLabel() {
        var parts: [String] = []
        if !dylibsToInject.isEmpty {
            let names = dylibsToInject.map { $0.lastPathComponent }.joined(separator: ", ")
            parts.append("\(L("待注入", "Injecting")): \(names)")
        }
        if !dylibsToRemove.isEmpty {
            let names = dylibsToRemove.joined(separator: ", ")
            parts.append("\(L("待移除", "Removing")): \(names)")
        }
        dylibLabel.text = parts.isEmpty ? L("暂未选择任何注入或移除的插件。", "No plugins selected for injection/removal.") : parts.joined(separator: "\n")
    }
    
    // MARK: - IPA Picker
    @objc private func showIPAPickerOptions() {
        let sheet = UIAlertController(title: L("选择 IPA 来源", "Choose IPA Source"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L("从内置「应用资源库」选取", "From App Library"), style: .default, handler: { [weak self] _ in
            self?.pickFromLibrary()
        }))
        sheet.addAction(UIAlertAction(title: L("从系统「文件」App 导入", "From Files App"), style: .default, handler: { [weak self] _ in
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
        let picker = UIDocumentPickerViewController(documentTypes: ["com.apple.itunes.ipa", "public.zip-archive"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if let imported = try? AppLibraryManager.shared.importIPA(from: url) {
            applySelectedIPA(imported)
        } else {
            applySelectedIPA(url)
        }
    }
    
    private func applySelectedIPA(_ url: URL) {
        selectedIPAURL = url
        ipaButton.setTitle("✓ " + url.lastPathComponent, for: .normal)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        let mb = Double(fileSize) / (1024 * 1024)
        ipaDetailLabel.text = String(format: L("已选择: %@ (%.1f MB)", "Selected: %@ (%.1f MB)"), url.lastPathComponent, mb)
        
        let rawName = url.deletingPathExtension().lastPathComponent
        if (nameField.text ?? "").isEmpty {
            nameField.text = rawName
        }
    }
    
    // MARK: - Icon Picker
    @objc private func chooseIcon() {
        let sheet = UIAlertController(title: L("更换应用图标", "Change App Icon"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L("从相册选取图片", "From Photo Library"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            self.present(picker, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: L("重置为原始图标", "Reset to Default"), style: .destructive, handler: { [weak self] _ in
            self?.selectedIconImage = nil
            self?.iconPreview.image = UIImage(systemName: "app.fill")
        }))
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let img = info[.originalImage] as? UIImage {
            selectedIconImage = img
            iconPreview.image = img
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
                    self.updateDylibLabel()
                }
            }))
        }
        sheet.addAction(UIAlertAction(title: L("从文件导入新插件", "Import from Files"), style: .default, handler: { [weak self] _ in
            let docPicker = UIDocumentPickerViewController(documentTypes: ["public.data", "public.item"], in: .import)
            docPicker.delegate = self
            self?.present(docPicker, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: L("清空已选插件", "Clear Selected"), style: .destructive, handler: { [weak self] _ in
            self?.dylibsToInject.removeAll()
            self?.updateDylibLabel()
        }))
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    @objc private func promptRemoveDylib() {
        let alert = UIAlertController(
            title: L("从 Mach-O 中移除插件", "Remove Dylib from Binary"),
            message: L("输入需要移除的动态库名称 (例如: Cycript.framework/Cycript 或 hook.dylib):", "Enter dylib name to remove:"),
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "hook.dylib" }
        alert.addAction(UIAlertAction(title: L("添加至移除列表", "Add to Removal List"), style: .destructive, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                self?.dylibsToRemove.append(text)
                self?.updateDylibLabel()
            }
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Signing Pipeline
    @objc private func startSigning() {
        guard let ipa = selectedIPAURL else {
            let alert = UIAlertController(title: L("提示", "Notice"), message: L("请先选择待签名的 IPA 文件！", "Please select an IPA file first!"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        
        let isAppleID = (signingMethodSegment.selectedSegmentIndex == 0)
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
        
        let customBundleId = bundleIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let customName = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let customVersion = versionField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let customMinOS = minOSField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let enableFileSharing = fileSharingSwitch.isOn
        let enableDocInPlace = docInPlaceSwitch.isOn
        
        let targetBundleID = (customBundleId != nil && !customBundleId!.isEmpty) ? customBundleId! : "com.unisign.app.\(UUID().uuidString.prefix(6))"
        let deviceUDID = DeviceInfoHelper.getDeviceUDID()
        
        let executeSigning: (URL, URL) -> Void = { [weak self] p12URL, provURL in
            guard let self = self else { return }
            
            IPAManager.shared.progressHandler = { step, pct in
                DispatchQueue.main.async {
                    ProgressHUD.shared.update(title: step, detail: "\(Int(pct * 100))%")
                }
            }
            
            IPAManager.shared.modifyAndSignIPA(
                sourceIPA: ipa,
                p12URL: p12URL,
                p12Password: "",
                mobileprovisionURL: provURL,
                newBundleId: (customBundleId?.isEmpty ?? true) ? nil : customBundleId,
                newDisplayName: (customName?.isEmpty ?? true) ? nil : customName,
                newVersion: (customVersion?.isEmpty ?? true) ? nil : customVersion,
                newMinOSVersion: (customMinOS?.isEmpty ?? true) ? nil : customMinOS,
                enableFileSharing: enableFileSharing,
                enableOpeningDocumentsInPlace: enableDocInPlace,
                newIconImage: self.selectedIconImage,
                dylibsToInject: self.dylibsToInject,
                dylibsToRemove: self.dylibsToRemove
            ) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    ProgressHUD.shared.hide()
                    
                    switch result {
                    case .success(let outputIPA):
                        self.signedIPAURL = outputIPA
                        self.installButton.isHidden = false
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        
                        let recordName = customName?.isEmpty == false ? customName! : ipa.deletingPathExtension().lastPathComponent
                        let recordVersion = customVersion?.isEmpty == false ? customVersion! : "1.0.0"
                        
                        _ = AppLibraryManager.shared.registerSignedApp(
                            ipaURL: outputIPA,
                            name: recordName,
                            bundleId: targetBundleID,
                            version: recordVersion,
                            signMethod: isAppleID ? "apple_id" : "p12",
                            appleIDEmail: isAppleID ? activeAccount?.email : nil,
                            expirationDate: Date().addingTimeInterval(7 * 24 * 3600)
                        )
                        self.updateAccountQuotaBadge()
                        
                        let alert = UIAlertController(
                            title: L("重签成功！", "Signing Successful!"),
                            message: "\(recordName) " + L("已成功打包签名！可直接点击下方按钮进行本地无线安装，或在应用资源库查看。", "has been signed and packaged! You can install it locally now."),
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "📲 " + L("立即安装 (OTA)", "Install Now"), style: .default, handler: { [weak self] _ in
                            self?.installAppLocally()
                        }))
                        alert.addAction(UIAlertAction(title: L("完成", "Done"), style: .cancel))
                        self.present(alert, animated: true)
                        
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
    
    @objc private func installAppLocally() {
        guard let signedURL = signedIPAURL else { return }
        do {
            try LocalInstallServer.shared.start()
            let bundleID = bundleIdField.text?.isEmpty == false ? bundleIdField.text! : "com.unisign.app"
            let appName = nameField.text?.isEmpty == false ? nameField.text! : "UniSign App"
            let installURL = LocalInstallServer.shared.generateInstallURL(ipaURL: signedURL, bundleID: bundleID, title: appName)
            UIApplication.shared.open(installURL, options: [:]) { success in
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        } catch {
            let alert = UIAlertController(title: L("本地安装服务异常", "Server Error"), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
