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
    
    // Form fields
    private let ipaButton = UIButton(type: .system)
    private let signingMethodSegment = UISegmentedControl(items: [
        L("当前活跃 Apple ID", "Active Apple ID"),
        L("P12 开发者证书", "P12 Certificate")
    ])
    private let bundleIdField = UITextField()
    private let nameField = UITextField()
    private let versionField = UITextField()
    private let minOSField = UITextField()
    private let fileSharingSwitch = UISwitch()
    private let docInPlaceSwitch = UISwitch()
    private let iconPreview = UIImageView()
    private let changeIconButton = UIButton(type: .system)
    private let dylibLabel = UILabel()
    private let addDylibBtn = UIButton(type: .system)
    private let removeDylibBtn = UIButton(type: .system)
    
    // Section Header labels
    private let section1 = UILabel()
    private let section2 = UILabel()
    private let section3 = UILabel()
    private let section4 = UILabel()
    private let section5 = UILabel()
    private let section6 = UILabel()
    private let section7 = UILabel()
    
    // Actions & Progress
    private let signButton = UIButton(type: .system)
    private let installButton = UIButton(type: .system)
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let statusLabel = UILabel()
    private let logTextView = UITextView()
    
    private var signedIPAURL: URL?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        updateTexts()
        
        if let preselected = preselectedIPAURL {
            applySelectedIPA(preselected)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 16
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // 1. Source IPA Selection
        addSectionHeader(section1)
        ipaButton.backgroundColor = .systemBlue
        ipaButton.setTitleColor(.white, for: .normal)
        ipaButton.layer.cornerRadius = 10
        ipaButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        ipaButton.addTarget(self, action: #selector(showIPAPickerOptions), for: .touchUpInside)
        contentView.addArrangedSubview(ipaButton)
        
        // 2. Signing Identity Method
        addSectionHeader(section2)
        signingMethodSegment.selectedSegmentIndex = 0
        contentView.addArrangedSubview(signingMethodSegment)
        
        // 3. Metadata Customization
        addSectionHeader(section3)
        bundleIdField.borderStyle = .roundedRect
        contentView.addArrangedSubview(bundleIdField)
        
        nameField.borderStyle = .roundedRect
        contentView.addArrangedSubview(nameField)
        
        let versionStack = UIStackView()
        versionStack.axis = .horizontal
        versionStack.spacing = 10
        versionStack.distribution = .fillEqually
        versionField.borderStyle = .roundedRect
        minOSField.borderStyle = .roundedRect
        versionStack.addArrangedSubview(versionField)
        versionStack.addArrangedSubview(minOSField)
        contentView.addArrangedSubview(versionStack)
        
        // 4. File Access Permissions
        addSectionHeader(section4)
        let switchRow1 = makeSwitchRow(title: L("开启文件共享 (UIFileSharingEnabled)", "Enable File Sharing (UIFileSharing)"), switchView: fileSharingSwitch)
        let switchRow2 = makeSwitchRow(title: L("支持文件 App 原地打开 (LSSupportsOpeningDocumentsInPlace)", "Open Documents In Place"), switchView: docInPlaceSwitch)
        fileSharingSwitch.isOn = true
        docInPlaceSwitch.isOn = true
        contentView.addArrangedSubview(switchRow1)
        contentView.addArrangedSubview(switchRow2)
        
        // 5. App Icon Replacement
        addSectionHeader(section5)
        let iconStack = UIStackView()
        iconStack.axis = .horizontal
        iconStack.spacing = 16
        iconStack.alignment = .center
        
        iconPreview.backgroundColor = .secondarySystemBackground
        iconPreview.layer.cornerRadius = 14
        iconPreview.clipsToBounds = true
        iconPreview.contentMode = .scaleAspectFill
        iconPreview.image = UIImage(systemName: "app.dashed")
        iconPreview.tintColor = .secondaryLabel
        iconPreview.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconPreview.heightAnchor.constraint(equalToConstant: 64).isActive = true
        
        changeIconButton.addTarget(self, action: #selector(chooseIcon), for: .touchUpInside)
        
        iconStack.addArrangedSubview(iconPreview)
        iconStack.addArrangedSubview(changeIconButton)
        contentView.addArrangedSubview(iconStack)
        
        // 6. Dylib Plugins
        addSectionHeader(section6)
        dylibLabel.font = .systemFont(ofSize: 13, weight: .regular)
        dylibLabel.textColor = .secondaryLabel
        contentView.addArrangedSubview(dylibLabel)
        
        let dylibBtnStack = UIStackView()
        dylibBtnStack.axis = .horizontal
        dylibBtnStack.spacing = 10
        dylibBtnStack.distribution = .fillEqually
        
        addDylibBtn.backgroundColor = .systemGray5
        addDylibBtn.layer.cornerRadius = 8
        addDylibBtn.addTarget(self, action: #selector(showDylibPickerOptions), for: .touchUpInside)
        
        removeDylibBtn.backgroundColor = .systemGray5
        removeDylibBtn.layer.cornerRadius = 8
        removeDylibBtn.addTarget(self, action: #selector(promptRemoveDylib), for: .touchUpInside)
        
        dylibBtnStack.addArrangedSubview(addDylibBtn)
        dylibBtnStack.addArrangedSubview(removeDylibBtn)
        contentView.addArrangedSubview(dylibBtnStack)
        
        // 7. Actions & Logs
        addSectionHeader(section7)
        signButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        signButton.backgroundColor = .systemGreen
        signButton.setTitleColor(.white, for: .normal)
        signButton.layer.cornerRadius = 12
        signButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        signButton.addTarget(self, action: #selector(startSigning), for: .touchUpInside)
        contentView.addArrangedSubview(signButton)
        
        progressBar.progress = 0.0
        progressBar.isHidden = true
        contentView.addArrangedSubview(progressBar)
        
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        contentView.addArrangedSubview(statusLabel)
        
        installButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        installButton.backgroundColor = .systemIndigo
        installButton.setTitleColor(.white, for: .normal)
        installButton.layer.cornerRadius = 10
        installButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        installButton.isHidden = true
        installButton.addTarget(self, action: #selector(installAppLocally), for: .touchUpInside)
        contentView.addArrangedSubview(installButton)
        
        logTextView.isEditable = false
        logTextView.backgroundColor = .black
        logTextView.textColor = .systemGreen
        logTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.layer.cornerRadius = 8
        logTextView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        contentView.addArrangedSubview(logTextView)
    }
    
    @objc private func languageDidChange() {
        updateTexts()
    }
    
    private func updateTexts() {
        title = L("签名与深度定制", "Sign & Customize")
        section1.text = L("1. 目标 IPA 安装包", "1. Source IPA")
        section2.text = L("2. 签名凭据方式", "2. Signing Identity")
        section3.text = L("3. 应用标识与信息定制", "3. Bundle & Metadata Customization")
        section4.text = L("4. 沙盒文件访问权限", "4. File Access & Storage Sharing")
        section5.text = L("5. 应用桌面图标替换", "5. App Icon Replacement")
        section6.text = L("6. 动态库插件注入与管理", "6. Dylib / Tweak Plugins")
        section7.text = L("7. 执行签名与重打包", "7. Signing & Repackaging")
        
        if selectedIPAURL == nil {
            ipaButton.setTitle(L("点击选择 IPA (支持从资源库或文件 App 选择)", "Select IPA (from Library or Files)"), for: .normal)
        }
        signingMethodSegment.setTitle(L("当前活跃 Apple ID", "Active Apple ID"), forSegmentAt: 0)
        signingMethodSegment.setTitle(L("P12 开发者证书", "P12 Certificate"), forSegmentAt: 1)
        
        bundleIdField.placeholder = L("新 Bundle ID (如 com.mod.app，留空保持原样)", "New Bundle Identifier (e.g. com.mod.app)")
        nameField.placeholder = L("桌面应用名称 (如 我的定制微信，留空保持原样)", "Display Name (e.g. My Modded App)")
        versionField.placeholder = L("版本号 (如 2.1.0)", "Version (e.g. 2.1.0)")
        minOSField.placeholder = L("最低系统版本 (如 13.0)", "Min OS (e.g. 13.0)")
        changeIconButton.setTitle(L("从相册选择新图标", "Choose Icon from Photos"), for: .normal)
        addDylibBtn.setTitle(L("+ 注入 Dylib 插件", "+ Select Dylib"), for: .normal)
        removeDylibBtn.setTitle(L("- 移除 Dylib 插件", "- Remove Dylib"), for: .normal)
        signButton.setTitle(L("开始签名并重新打包", "Start Signing IPA"), for: .normal)
        installButton.setTitle(L("🚀 本地一键安装应用 (OTA 免越狱)", "🚀 Install Signed App Locally"), for: .normal)
        statusLabel.text = L("就绪，等待配置完成。", "Ready to customize and sign.")
        logTextView.text = L("[UniSign 签名引擎就绪]\n请选择需要签名的 IPA 安装包。\n", "[UniSign Engine initialized]\nReady for signing.\n")
        updateDylibLabel()
    }
    
    private func addSectionHeader(_ label: UILabel) {
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        contentView.addArrangedSubview(label)
    }
    
    private func makeSwitchRow(title: String, switchView: UISwitch) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing
        let lbl = UILabel()
        lbl.text = title
        lbl.font = .systemFont(ofSize: 14)
        row.addArrangedSubview(lbl)
        row.addArrangedSubview(switchView)
        return row
    }
    
    // MARK: - Picker Actions
    
    @objc private func showIPAPickerOptions() {
        let sheet = UIAlertController(title: L("选择待签名 IPA", "Select Source IPA"), message: nil, preferredStyle: .actionSheet)
        
        let libraryIPAs = AppLibraryManager.shared.getUnsignedIPAs()
        if !libraryIPAs.isEmpty {
            sheet.addAction(UIAlertAction(title: "\(L("从内部资源库选择", "Pick from App Library")) (\(libraryIPAs.count))", style: .default, handler: { [weak self] _ in
                self?.showLibraryIPAPicker(libraryIPAs)
            }))
        }
        
        sheet.addAction(UIAlertAction(title: L("从 iOS“文件”App 导入", "Import from Files App"), style: .default, handler: { [weak self] _ in
            self?.openSystemDocumentPicker()
        }))
        
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func showLibraryIPAPicker(_ ipas: [URL]) {
        let pickerAlert = UIAlertController(title: L("从资源库选取 IPA", "Choose IPA from Library"), message: nil, preferredStyle: .actionSheet)
        for ipa in ipas {
            pickerAlert.addAction(UIAlertAction(title: ipa.lastPathComponent, style: .default, handler: { [weak self] _ in
                self?.applySelectedIPA(ipa)
            }))
        }
        pickerAlert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(pickerAlert, animated: true)
    }
    
    private func applySelectedIPA(_ url: URL) {
        self.selectedIPAURL = url
        self.ipaButton.setTitle("\(L("已选择", "Selected")): \(url.lastPathComponent)", for: .normal)
        self.ipaButton.backgroundColor = .systemIndigo
        appendLog("[+] \(L("已选定安装包", "Selected IPA")): \(url.lastPathComponent)")
    }
    
    private func openSystemDocumentPicker() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.zip-archive", "com.apple.itunes.ipa", "public.data"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    @objc private func showDylibPickerOptions() {
        let sheet = UIAlertController(title: L("选择注入的 Dylib 插件", "Inject Dylib"), message: nil, preferredStyle: .actionSheet)
        
        let libraryDylibs = AppLibraryManager.shared.getImportedDylibs()
        if !libraryDylibs.isEmpty {
            sheet.addAction(UIAlertAction(title: "\(L("从插件仓库勾选", "Choose from Library Plugins")) (\(libraryDylibs.count))", style: .default, handler: { [weak self] _ in
                self?.showLibraryDylibPicker(libraryDylibs)
            }))
        }
        
        sheet.addAction(UIAlertAction(title: L("从文件 App 导入新插件", "Import from Files App"), style: .default, handler: { [weak self] _ in
            let picker = UIDocumentPickerViewController(documentTypes: ["public.data", "public.item"], in: .import)
            picker.delegate = self
            picker.allowsMultipleSelection = true
            self?.present(picker, animated: true)
        }))
        
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func showLibraryDylibPicker(_ dylibs: [URL]) {
        let pickerAlert = UIAlertController(title: L("选择注入插件", "Choose Dylib Plugin"), message: nil, preferredStyle: .actionSheet)
        for d in dylibs {
            pickerAlert.addAction(UIAlertAction(title: d.lastPathComponent, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                if !self.dylibsToInject.contains(d) {
                    self.dylibsToInject.append(d)
                    self.appendLog("[+] \(L("已添加注入插件", "Injected library plugin")): \(d.lastPathComponent)")
                    self.updateDylibLabel()
                }
            }))
        }
        pickerAlert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(pickerAlert, animated: true)
    }
    
    @objc private func chooseIcon() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
    
    @objc private func promptRemoveDylib() {
        let alert = UIAlertController(
            title: L("移除指定动态库", "Remove Dylib"),
            message: L("输入需要从 Mach-O 中剥离清除的插件文件名 (如 Tweak.dylib)：", "Enter the dylib filename to strip from Mach-O:"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in tf.placeholder = "PluginName.dylib" }
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("确认移除", "Remove"), style: .destructive, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                self?.dylibsToRemove.append(text)
                self?.updateDylibLabel()
            }
        }))
        present(alert, animated: true)
    }
    
    private func updateDylibLabel() {
        dylibLabel.text = "\(L("已勾选注入", "Injected")): \(dylibsToInject.count) | \(L("计划移除", "Removed")): \(dylibsToRemove.count)"
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        if url.pathExtension.lowercased() == "ipa" || url.pathExtension.lowercased() == "zip" {
            let imported = (try? AppLibraryManager.shared.importIPA(from: url)) ?? url
            applySelectedIPA(imported)
        } else {
            for u in urls {
                let imported = (try? AppLibraryManager.shared.importDylib(from: u)) ?? u
                if !dylibsToInject.contains(imported) {
                    dylibsToInject.append(imported)
                    appendLog("[+] \(L("暂存插件", "Staged dylib")): \(imported.lastPathComponent)")
                }
            }
            updateDylibLabel()
        }
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let img = info[.originalImage] as? UIImage {
            self.selectedIconImage = img
            self.iconPreview.image = img
            appendLog("[+] \(L("已选定新应用图标", "New AppIcon selected"))")
        }
        picker.dismiss(animated: true)
    }
    
    // MARK: - Signing Pipeline
    
    @objc private func startSigning() {
        guard let ipaURL = selectedIPAURL else {
            showAlert(L("请先选择需要签名的 IPA 安装包！", "Please select an IPA file first."))
            return
        }
        
        signButton.isEnabled = false
        progressBar.isHidden = false
        progressBar.progress = 0.0
        statusLabel.text = L("正在初始化签名流水线...", "Starting signing process...")
        appendLog("[*] \(L("启动签名流水线...", "Initializing signing pipeline..."))")
        
        let options = PlistModifier.CustomizationOptions(
            bundleIdentifier: bundleIdField.text,
            displayName: nameField.text,
            versionString: versionField.text,
            minimumOSVersion: minOSField.text,
            enableFileSharing: fileSharingSwitch.isOn,
            enableDocumentInPlace: docInPlaceSwitch.isOn
        )
        
        let isAppleID = (signingMethodSegment.selectedSegmentIndex == 0)
        let activeAccount = AppleAccountManager.shared.getActiveAccount()
        
        if isAppleID {
            guard let active = activeAccount else {
                showAlert(L("未检测到活跃 Apple ID 账号。请先在“证书与UDID”页添加并登录 Apple ID，或切换为 P12 证书签名。", "No active Apple ID found."))
                signButton.isEnabled = true
                return
            }
            if AppleAccountManager.shared.hasReachedQuota(for: active.email) {
                showAlert(L("⚠️ Apple ID 配额已满 (3/3): 当前账号 (\(active.email)) 已激活 3 个应用。苹果免费开发者账号同设备最多仅允许 3 个应用。请先在资源库中删除无用应用，或在证书页切换到另一个 Apple ID。", "⚠️ Apple ID Quota Full (3/3)"))
                signButton.isEnabled = true
                return
            }
        }
        
        let dummyP12 = FileManager.default.temporaryDirectory.appendingPathComponent("dev.p12")
        try? Data([0x30, 0x82]).write(to: dummyP12)
        
        let config = IPAManager.SignConfig(
            ipaURL: ipaURL,
            p12URL: dummyP12,
            p12Password: "",
            provisionURL: nil,
            options: options,
            replacementIcon: selectedIconImage,
            dylibsToInject: dylibsToInject,
            dylibsToRemove: dylibsToRemove
        )
        
        IPAManager.processAndSign(config: config, progress: { [weak self] pct, message in
            DispatchQueue.main.async {
                self?.progressBar.setProgress(Float(pct), animated: true)
                self?.statusLabel.text = message
                self?.appendLog(message)
            }
        }) { [weak self] result in
            DispatchQueue.main.async {
                self?.signButton.isEnabled = true
                switch result {
                case .success(let outputURL):
                    self?.signedIPAURL = outputURL
                    self?.statusLabel.text = L("✓ 签名打包完成！", "Signed Successfully!")
                    self?.statusLabel.textColor = .systemGreen
                    self?.installButton.isHidden = false
                    self?.appendLog("[✓] \(L("签名完成，安装包已输出至", "Signed output saved at")): \(outputURL.path)")
                    
                    let appName = self?.nameField.text?.isEmpty == false ? self!.nameField.text! : ipaURL.deletingPathExtension().lastPathComponent
                    let bundleId = self?.bundleIdField.text?.isEmpty == false ? self!.bundleIdField.text! : "com.unisign.app"
                    let version = self?.versionField.text?.isEmpty == false ? self!.versionField.text! : "1.0.0"
                    let expiry = isAppleID ? Date().addingTimeInterval(7 * 24 * 3600) : Date().addingTimeInterval(365 * 24 * 3600)
                    
                    let record = SignedAppRecord(
                        name: appName,
                        bundleId: bundleId,
                        version: version,
                        signedDate: Date(),
                        expiryDate: expiry,
                        signMethod: isAppleID ? "apple_id" : "p12",
                        appleIDEmail: activeAccount?.email,
                        fileName: outputURL.lastPathComponent
                    )
                    AppLibraryManager.shared.recordSignedApp(record)
                    
                    self?.showAlert(L("签名完成！该应用已归档保存至你的应用资源库。", "Signing Complete! Saved to Library."))
                case .failure(let err):
                    self?.statusLabel.text = L("签名失败", "Signing Failed")
                    self?.statusLabel.textColor = .systemRed
                    self?.appendLog("[!] \(L("错误", "Error")): \(err.localizedDescription)")
                    self?.showAlert("\(L("签名遇到错误", "Signing Error")): \(err.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func installAppLocally() {
        guard let outputURL = signedIPAURL else { return }
        let bundleID = bundleIdField.text?.isEmpty == false ? bundleIdField.text! : "com.unisign.app"
        let title = nameField.text?.isEmpty == false ? nameField.text! : "Signed App"
        let version = versionField.text?.isEmpty == false ? versionField.text! : "1.0.0"
        
        LocalInstallServer.shared.startServing(ipaURL: outputURL, bundleID: bundleID, version: version, title: title) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let installURL):
                    self?.appendLog("[*] \(L("唤起 itms-services 本地系统安装器", "Triggering itms-services installation")): \(installURL.absoluteString)")
                    UIApplication.shared.open(installURL, options: [:], completionHandler: nil)
                case .failure(let err):
                    self?.showAlert("\(L("本地 Web 服务错误", "Local Server Error")): \(err.localizedDescription)")
                }
            }
        }
    }
    
    private func appendLog(_ message: String) {
        logTextView.text.append("\(message)\n")
        let bottom = NSRange(location: logTextView.text.count - 1, length: 1)
        logTextView.scrollRangeToVisible(bottom)
    }
    
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "UniSign", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
