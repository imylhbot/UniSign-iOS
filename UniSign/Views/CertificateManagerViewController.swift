import UIKit

public class CertificateManagerViewController: UIViewController, UIDocumentPickerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    private let segmentedControl = UISegmentedControl(items: [
        L("Apple ID 中心", "Apple ID Center"),
        L("P12 商业证书", "P12 Certificates"),
        L("本机 UDID", "Device UDID")
    ])
    private let containerView = UIView()
    
    // P12 Section Views
    private let p12ScrollView = UIScrollView()
    private let p12Stack = UIStackView()
    private let p12Card = CardView()
    private let importP12Button = GradientButton(title: "", style: .primaryCyber, icon: UIImage(systemName: "key.fill"))
    private let importProvisionButton = GradientButton(title: "", style: .secondaryGray, icon: UIImage(systemName: "doc.text.fill"))
    private let p12PasswordField = UITextField()
    private let certStatusCard = CardView()
    private let certStatusLabel = UILabel()
    private let certValidityBadge = PillBadge(text: "", style: .info)
    
    // Apple ID Section Views
    private let appleIDView = UIStackView()
    private let appleTableView = UITableView(frame: .zero, style: .insetGrouped)
    private let addAccountButton = GradientButton(
        title: "",
        style: .appleBrand,
        icon: UIImage(systemName: "applelogo")
    )
    
    // UDID Section Views
    private let udidCard = CardView()
    private let udidLabel = UILabel()
    private let copyUDIDButton = GradientButton(title: "", style: .primaryCyber, icon: UIImage(systemName: "doc.on.doc.fill"))
    private let editUDIDButton = UIButton(type: .system)
    private let udidTitleLabel = UILabel()
    private let udidIconView = UIImageView()
    
    private var importedP12URL: URL?
    private var importedProvisionURL: URL?
    private var appleAccounts: [AppleAccount] = []
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupUI()
        updateTexts()
        reloadAppleAccounts()
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadAppleAccounts()
        updateUDIDDisplay()
    }
    
    private func setupUI() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 36),
            
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        setupAppleIDSection()
        setupP12Section()
        setupUDIDSection()
        segmentChanged()
    }
    
    @objc private func languageDidChange() {
        updateTexts()
        appleTableView.reloadData()
    }
    
    private func updateTexts() {
        title = L("证书与设备中心", "Certificates & Devices")
        segmentedControl.setTitle(L("Apple ID 中心", "Apple ID"), forSegmentAt: 0)
        segmentedControl.setTitle(L("P12 商业证书", "P12 Certs"), forSegmentAt: 1)
        segmentedControl.setTitle(L("本机 UDID", "Device UDID"), forSegmentAt: 2)
        
        importP12Button.setTitle(L("导入 .p12 开发者证书", "Import .p12 Certificate"), for: .normal)
        p12PasswordField.placeholder = L("证书密码 (无密码请留空)", "P12 Password (Leave empty if none)")
        importProvisionButton.setTitle(L("导入 .mobileprovision 描述文件", "Import .mobileprovision Profile"), for: .normal)
        addAccountButton.setTitle(L("+ 添加 Apple ID (每账号限 3 个应用)", "+ Add Apple ID (Max 3 apps per ID)"), for: .normal)
        udidTitleLabel.text = L("本机设备识别码 (UDID)", "Device UDID")
        copyUDIDButton.setTitle(L("复制设备 UDID", "Copy Device UDID"), for: .normal)
        editUDIDButton.setTitle(L("✏️ 手动输入 / 自定义 UDID", "✏️ Customize / Override UDID"), for: .normal)
    }
    
    // MARK: - 1. Apple ID Section
    private func setupAppleIDSection() {
        appleIDView.axis = .vertical
        appleIDView.spacing = 12
        appleIDView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(appleIDView)
        
        NSLayoutConstraint.activate([
            appleIDView.topAnchor.constraint(equalTo: containerView.topAnchor),
            appleIDView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            appleIDView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            appleIDView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        addAccountButton.translatesAutoresizingMaskIntoConstraints = false
        addAccountButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        addAccountButton.addTarget(self, action: #selector(promptAddAppleAccount), for: .touchUpInside)
        headerContainer.addSubview(addAccountButton)
        
        NSLayoutConstraint.activate([
            addAccountButton.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            addAccountButton.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4),
            addAccountButton.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            addAccountButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16)
        ])
        appleIDView.addArrangedSubview(headerContainer)
        
        appleTableView.delegate = self
        appleTableView.dataSource = self
        appleTableView.backgroundColor = .clear
        appleTableView.separatorStyle = .singleLine
        appleIDView.addArrangedSubview(appleTableView)
    }
    
    // MARK: - 2. P12 Section
    private func setupP12Section() {
        p12ScrollView.translatesAutoresizingMaskIntoConstraints = false
        p12ScrollView.alwaysBounceVertical = true
        containerView.addSubview(p12ScrollView)
        
        p12Stack.axis = .vertical
        p12Stack.spacing = 16
        p12Stack.translatesAutoresizingMaskIntoConstraints = false
        p12ScrollView.addSubview(p12Stack)
        
        NSLayoutConstraint.activate([
            p12ScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            p12ScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            p12ScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            p12ScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            p12Stack.topAnchor.constraint(equalTo: p12ScrollView.topAnchor, constant: 8),
            p12Stack.leadingAnchor.constraint(equalTo: p12ScrollView.leadingAnchor, constant: 16),
            p12Stack.trailingAnchor.constraint(equalTo: p12ScrollView.trailingAnchor, constant: -16),
            p12Stack.bottomAnchor.constraint(equalTo: p12ScrollView.bottomAnchor, constant: -20),
            p12Stack.widthAnchor.constraint(equalTo: p12ScrollView.widthAnchor, constant: -32)
        ])
        
        // P12 Form Card
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        p12Card.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: p12Card.topAnchor, constant: 16),
            cardStack.bottomAnchor.constraint(equalTo: p12Card.bottomAnchor, constant: -16),
            cardStack.leadingAnchor.constraint(equalTo: p12Card.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: p12Card.trailingAnchor, constant: -16)
        ])
        
        importP12Button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        importP12Button.addTarget(self, action: #selector(importP12Action), for: .touchUpInside)
        cardStack.addArrangedSubview(importP12Button)
        
        p12PasswordField.isSecureTextEntry = true
        p12PasswordField.borderStyle = .roundedRect
        p12PasswordField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        cardStack.addArrangedSubview(p12PasswordField)
        
        importProvisionButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        importProvisionButton.addTarget(self, action: #selector(importProvisionAction), for: .touchUpInside)
        cardStack.addArrangedSubview(importProvisionButton)
        
        let verifyBtn = UIButton(type: .system)
        verifyBtn.setTitle(L("🔍 校验密码并计算证书有效天数", "🔍 Verify & Calculate Validity"), for: .normal)
        verifyBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        verifyBtn.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        verifyBtn.setTitleColor(.systemBlue, for: .normal)
        verifyBtn.layer.cornerRadius = 10
        verifyBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        verifyBtn.addTarget(self, action: #selector(verifyP12), for: .touchUpInside)
        cardStack.addArrangedSubview(verifyBtn)
        
        p12Stack.addArrangedSubview(p12Card)
        
        // Status Card
        let statusStack = UIStackView()
        statusStack.axis = .vertical
        statusStack.spacing = 10
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        certStatusCard.addSubview(statusStack)
        
        NSLayoutConstraint.activate([
            statusStack.topAnchor.constraint(equalTo: certStatusCard.topAnchor, constant: 16),
            statusStack.bottomAnchor.constraint(equalTo: certStatusCard.bottomAnchor, constant: -16),
            statusStack.leadingAnchor.constraint(equalTo: certStatusCard.leadingAnchor, constant: 16),
            statusStack.trailingAnchor.constraint(equalTo: certStatusCard.trailingAnchor, constant: -16)
        ])
        
        let badgeRow = UIStackView()
        badgeRow.axis = .horizontal
        badgeRow.spacing = 8
        badgeRow.alignment = .center
        
        let statusTitle = UILabel()
        statusTitle.text = L("证书状态信息", "Certificate Details")
        statusTitle.font = .systemFont(ofSize: 15, weight: .bold)
        badgeRow.addArrangedSubview(statusTitle)
        badgeRow.addArrangedSubview(UIView())
        badgeRow.addArrangedSubview(certValidityBadge)
        certValidityBadge.update(text: L("未载入", "None"), style: .info)
        statusStack.addArrangedSubview(badgeRow)
        
        certStatusLabel.text = L("尚未导入 P12 证书文件。", "No P12 certificate loaded.")
        certStatusLabel.numberOfLines = 0
        certStatusLabel.font = .systemFont(ofSize: 13)
        certStatusLabel.textColor = .secondaryLabel
        statusStack.addArrangedSubview(certStatusLabel)
        
        p12Stack.addArrangedSubview(certStatusCard)
    }
    
    // MARK: - 3. UDID Section
    private func setupUDIDSection() {
        udidCard.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(udidCard)
        
        NSLayoutConstraint.activate([
            udidCard.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            udidCard.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            udidCard.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        let udidStack = UIStackView()
        udidStack.axis = .vertical
        udidStack.spacing = 16
        udidStack.alignment = .fill
        udidStack.translatesAutoresizingMaskIntoConstraints = false
        udidCard.addSubview(udidStack)
        
        NSLayoutConstraint.activate([
            udidStack.topAnchor.constraint(equalTo: udidCard.topAnchor, constant: 20),
            udidStack.bottomAnchor.constraint(equalTo: udidCard.bottomAnchor, constant: -20),
            udidStack.leadingAnchor.constraint(equalTo: udidCard.leadingAnchor, constant: 16),
            udidStack.trailingAnchor.constraint(equalTo: udidCard.trailingAnchor, constant: -16)
        ])
        
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .center
        
        udidIconView.image = UIImage(systemName: "iphone.gen3")?.withRenderingMode(.alwaysTemplate)
        udidIconView.tintColor = .systemBlue
        udidIconView.contentMode = .scaleAspectFit
        udidIconView.translatesAutoresizingMaskIntoConstraints = false
        udidIconView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        udidIconView.heightAnchor.constraint(equalToConstant: 28).isActive = true
        headerRow.addArrangedSubview(udidIconView)
        
        udidTitleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        headerRow.addArrangedSubview(udidTitleLabel)
        udidStack.addArrangedSubview(headerRow)
        
        udidLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        udidLabel.textColor = .label
        udidLabel.numberOfLines = 0
        udidLabel.textAlignment = .center
        udidLabel.backgroundColor = UIColor.label.withAlphaComponent(0.05)
        udidLabel.layer.cornerRadius = 10
        udidLabel.layer.masksToBounds = true
        udidLabel.heightAnchor.constraint(equalToConstant: 54).isActive = true
        udidStack.addArrangedSubview(udidLabel)
        
        copyUDIDButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        copyUDIDButton.addTarget(self, action: #selector(copyUDIDAction), for: .touchUpInside)
        udidStack.addArrangedSubview(copyUDIDButton)
        
        editUDIDButton.setTitleColor(.secondaryLabel, for: .normal)
        editUDIDButton.titleLabel?.font = .systemFont(ofSize: 14)
        editUDIDButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        editUDIDButton.addTarget(self, action: #selector(editUDIDAction), for: .touchUpInside)
        udidStack.addArrangedSubview(editUDIDButton)
        
        updateUDIDDisplay()
    }
    
    private func updateUDIDDisplay() {
        udidLabel.text = DeviceInfoHelper.getDeviceUDID()
    }
    
    @objc private func copyUDIDAction() {
        DeviceInfoHelper.copyUDIDToClipboard()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let alert = UIAlertController(title: L("已复制", "Copied"), message: L("设备 UDID 已成功复制到系统剪贴板！", "UDID copied to clipboard!"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func editUDIDAction() {
        let alert = UIAlertController(
            title: L("自定义设备 UDID", "Override Device UDID"),
            message: L("请输入您的 40 位或 25 位官方设备识别码：", "Enter your official 40-character or 25-character UDID:"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.text = DeviceInfoHelper.getDeviceUDID()
        }
        alert.addAction(UIAlertAction(title: L("保存", "Save"), style: .default, handler: { [weak self] _ in
            if let val = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
                DeviceInfoHelper.setCustomUDID(val)
                self?.updateUDIDDisplay()
            }
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func segmentChanged() {
        appleIDView.isHidden = (segmentedControl.selectedSegmentIndex != 0)
        p12ScrollView.isHidden = (segmentedControl.selectedSegmentIndex != 1)
        udidCard.isHidden = (segmentedControl.selectedSegmentIndex != 2)
    }
    
    @objc private func promptAddAppleAccount() {
        let loginVC = AppleIDLoginViewController()
        loginVC.onLoginSuccess = { [weak self] in
            self?.reloadAppleAccounts()
        }
        present(loginVC, animated: true)
    }
    
    private func reloadAppleAccounts() {
        appleAccounts = AppleAccountManager.shared.accounts
        appleTableView.reloadData()
    }
    
    // MARK: - TableView (Apple Accounts)
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return appleAccounts.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "AppleAccCell")
        let acc = appleAccounts[indexPath.row]
        let count = AppleAccountManager.shared.activeAppsCount(for: acc.email)
        let isFull = count >= AppleAccountManager.maxAppsPerAppleID
        
        cell.backgroundColor = UniSignTheme.cardBackground
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true
        
        cell.imageView?.image = UIImage(systemName: "applelogo")?.withRenderingMode(.alwaysTemplate)
        cell.imageView?.tintColor = acc.isActive ? UniSignTheme.appleOrange : .secondaryLabel
        
        cell.textLabel?.text = acc.email
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        
        let quotaText = isFull ? "⚠️ " + L("配额已满 (3/3)", "Quota Full (3/3)") : "\(L("配额", "Quota")): \(count)/3 \(L("应用", "Apps"))"
        let activeTag = acc.isActive ? "• [" + L("当前签名默认账号", "ACTIVE SIGNER") + "]" : ""
        cell.detailTextLabel?.text = "\(acc.teamName ?? acc.teamID ?? L("个人开发者团队", "Personal Team")) • \(quotaText) \(activeTag)"
        cell.detailTextLabel?.textColor = isFull ? .systemRed : .secondaryLabel
        cell.detailTextLabel?.font = .systemFont(ofSize: 12)
        
        cell.accessoryType = acc.isActive ? .checkmark : .disclosureIndicator
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let acc = appleAccounts[indexPath.row]
        let count = AppleAccountManager.shared.activeAppsCount(for: acc.email)
        
        let sheet = UIAlertController(
            title: acc.email,
            message: "\(L("当前活跃签名应用数", "Active Signed Apps")): \(count)/3",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: L("设为当前默认签名账号", "Set as Active Signing Account"), style: .default, handler: { [weak self] _ in
            AppleAccountManager.shared.setActiveAccount(id: acc.id)
            self?.reloadAppleAccounts()
        }))
        sheet.addAction(UIAlertAction(title: "\(L("查看已签应用与一键续期", "View Signed Apps & Renew")) (\(count))", style: .default, handler: { [weak self] _ in
            self?.showAppsForAccount(acc)
        }))
        sheet.addAction(UIAlertAction(title: L("删除此账号", "Delete Account"), style: .destructive, handler: { [weak self] _ in
            AppleAccountManager.shared.removeAccount(id: acc.id)
            self?.reloadAppleAccounts()
        }))
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func showAppsForAccount(_ acc: AppleAccount) {
        let signedApps = AppleAccountManager.shared.signedApps(for: acc.email)
        let alert = UIAlertController(title: "\(acc.email) - " + L("已签应用", "Signed Apps"), message: nil, preferredStyle: .actionSheet)
        
        if signedApps.isEmpty {
            alert.message = L("当前账号暂无签名的应用。", "No apps currently signed with this Apple ID.")
        } else {
            for app in signedApps {
                let exp = app.isExpired ? L("已过期", "Expired") : "\(app.daysRemaining) " + L("天后到期", "days left")
                alert.addAction(UIAlertAction(title: "⚡️ \(app.name) (v\(app.version)) - \(exp)", style: .default, handler: { [weak self] _ in
                    self?.renewApp(app)
                }))
            }
        }
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .cancel))
        present(alert, animated: true)
    }
    
    private func renewApp(_ app: SignedAppRecord) {
        ProgressHUD.shared.show(in: view, title: L("正在执行一键续期...", "Renewing Certificate..."), detail: app.name)
        RenewalService.shared.renewSignedApp(app) { [weak self] (result: Result<SignedAppRecord, Error>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                ProgressHUD.shared.hide()
                switch result {
                case .success(let renewed):
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    let successAlert = UIAlertController(
                        title: L("续期成功！", "Renewed!"),
                        message: "\(renewed.name) " + L("已成功续期 7 天！", "has been renewed for 7 days!"),
                        preferredStyle: .alert
                    )
                    successAlert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                    self.present(successAlert, animated: true)
                    self.reloadAppleAccounts()
                case .failure(let err):
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    let errAlert = UIAlertController(title: L("续期失败", "Renewal Failed"), message: err.localizedDescription, preferredStyle: .alert)
                    errAlert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                    self.present(errAlert, animated: true)
                }
            }
        }
    }
    
    // MARK: - P12 Logic
    @objc private func importP12Action() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data", "com.rsa.pkcs-12"], in: .import)
        picker.delegate = self
        picker.modalPresentationStyle = .formSheet
        present(picker, animated: true)
    }
    
    @objc private func importProvisionAction() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data", "public.item"], in: .import)
        picker.delegate = self
        picker.modalPresentationStyle = .formSheet
        present(picker, animated: true)
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let ext = url.pathExtension.lowercased()
        if ext == "p12" {
            importedP12URL = url
            importP12Button.setTitle("✓ " + url.lastPathComponent, for: .normal)
            importP12Button.buttonStyle = .primaryCyber
        } else if ext == "mobileprovision" {
            importedProvisionURL = url
            importProvisionButton.setTitle("✓ " + url.lastPathComponent, for: .normal)
            importProvisionButton.buttonStyle = .primaryCyber
        }
    }
    
    @objc private func verifyP12() {
        guard let p12 = importedP12URL else {
            let alert = UIAlertController(title: L("提示", "Notice"), message: L("请先导入 .p12 证书文件！", "Please import a .p12 certificate first!"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        
        let pass = p12PasswordField.text ?? ""
        do {
            let info = try ZSignBridge.inspectP12(p12Path: p12.path, password: pass)
            let days = info["daysRemaining"] as? Int ?? 0
            let valid = info["isValid"] as? Bool ?? false
            let subject = info["subject"] as? String ?? L("未知", "Unknown")
            
            if valid {
                certValidityBadge.update(text: "\(days) " + L("天有效", "Days Left"), style: .success)
                certStatusLabel.text = "\(L("证书主题", "Subject")): \(subject)\n\(L("状态", "Status")): " + L("有效", "Valid")
            } else {
                certValidityBadge.update(text: L("已过期", "Expired"), style: .danger)
                certStatusLabel.text = "\(L("证书主题", "Subject")): \(subject)\n\(L("状态", "Status")): " + L("已过期或密码不符", "Expired or wrong password")
            }
        } catch {
            certValidityBadge.update(text: L("解析失败", "Error"), style: .danger)
            certStatusLabel.text = L("无法解析该 P12，请检查密码是否正确：", "Failed to parse P12, verify password: ") + error.localizedDescription
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
