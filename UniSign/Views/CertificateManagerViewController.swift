import UIKit

public class CertificateManagerViewController: UIViewController, UIDocumentPickerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    private let segmentedControl = UISegmentedControl(items: [
        L("P12 证书管理", "P12 Certificates"),
        L("Apple ID 中心", "Apple ID Center"),
        L("本机 UDID", "Device UDID")
    ])
    private let containerView = UIView()
    
    // P12 Section Views
    private let p12View = UIStackView()
    private let importP12Button = UIButton(type: .system)
    private let importProvisionButton = UIButton(type: .system)
    private let p12PasswordField = UITextField()
    private let certStatusLabel = UILabel()
    
    // Apple ID Section Views
    private let appleIDView = UIStackView()
    private let appleTableView = UITableView(frame: .zero, style: .insetGrouped)
    private let addAccountButton = UIButton(type: .system)
    
    // UDID Section Views
    private let udidView = UIStackView()
    private let udidLabel = UILabel()
    private let copyUDIDButton = UIButton(type: .system)
    private let editUDIDButton = UIButton(type: .system)
    private let udidTitleLabel = UILabel()
    
    private var importedP12URL: URL?
    private var importedProvisionURL: URL?
    private var appleAccounts: [AppleAccount] = []
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
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
            
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        setupP12Section()
        setupAppleIDSection()
        setupUDIDSection()
        segmentChanged()
    }
    
    @objc private func languageDidChange() {
        updateTexts()
        appleTableView.reloadData()
    }
    
    private func updateTexts() {
        title = L("证书与设备 UDID", "Certificates & UDID")
        segmentedControl.setTitle(L("P12 证书管理", "P12 Certificates"), forSegmentAt: 0)
        segmentedControl.setTitle(L("Apple ID 中心", "Apple ID Center"), forSegmentAt: 1)
        segmentedControl.setTitle(L("本机 UDID", "Device UDID"), forSegmentAt: 2)
        
        importP12Button.setTitle(L("1. 导入 .p12 开发者证书", "1. Import .p12 Certificate"), for: .normal)
        p12PasswordField.placeholder = L("证书密码 (无密码请留空)", "P12 Password (Leave empty if none)")
        importProvisionButton.setTitle(L("2. 导入 .mobileprovision 描述文件", "2. Import .mobileprovision Profile"), for: .normal)
        addAccountButton.setTitle(L("+ 添加 Apple ID (每账号限3个应用)", "+ Add Apple ID (Max 3 apps per ID)"), for: .normal)
        udidTitleLabel.text = L("本机设备识别码 (Unique Device Identifier)", "Device UDID (Unique Device Identifier)")
        copyUDIDButton.setTitle(L("📋 复制本机 UDID 到剪贴板", "📋 Copy UDID to Clipboard"), for: .normal)
        editUDIDButton.setTitle(L("✏️ 手动修改 / 覆写 UDID", "✏️ Customize / Override UDID"), for: .normal)
    }
    
    // MARK: - 1. P12 Section
    private func setupP12Section() {
        p12View.axis = .vertical
        p12View.spacing = 16
        p12View.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(p12View)
        
        NSLayoutConstraint.activate([
            p12View.topAnchor.constraint(equalTo: containerView.topAnchor),
            p12View.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            p12View.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        importP12Button.backgroundColor = .systemBlue
        importP12Button.setTitleColor(.white, for: .normal)
        importP12Button.layer.cornerRadius = 10
        importP12Button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        importP12Button.addTarget(self, action: #selector(importP12Action), for: .touchUpInside)
        p12View.addArrangedSubview(importP12Button)
        
        p12PasswordField.isSecureTextEntry = true
        p12PasswordField.borderStyle = .roundedRect
        p12View.addArrangedSubview(p12PasswordField)
        
        importProvisionButton.backgroundColor = .systemTeal
        importProvisionButton.setTitleColor(.white, for: .normal)
        importProvisionButton.layer.cornerRadius = 10
        importProvisionButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        importProvisionButton.addTarget(self, action: #selector(importProvisionAction), for: .touchUpInside)
        p12View.addArrangedSubview(importProvisionButton)
        
        let verifyBtn = UIButton(type: .system)
        verifyBtn.setTitle(L("校验密码并计算证书有效天数", "Verify & Calculate Validity"), for: .normal)
        verifyBtn.backgroundColor = .systemGray5
        verifyBtn.layer.cornerRadius = 8
        verifyBtn.addTarget(self, action: #selector(verifyP12), for: .touchUpInside)
        p12View.addArrangedSubview(verifyBtn)
        
        certStatusLabel.text = L("尚未载入 P12 证书。", "No P12 certificate loaded.")
        certStatusLabel.numberOfLines = 0
        certStatusLabel.font = .systemFont(ofSize: 14)
        certStatusLabel.textColor = .secondaryLabel
        p12View.addArrangedSubview(certStatusLabel)
    }
    
    // MARK: - 2. Apple ID Section
    private func setupAppleIDSection() {
        appleIDView.axis = .vertical
        appleIDView.spacing = 10
        appleIDView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(appleIDView)
        
        NSLayoutConstraint.activate([
            appleIDView.topAnchor.constraint(equalTo: containerView.topAnchor),
            appleIDView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            appleIDView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            appleIDView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        let btnWrapper = UIView()
        btnWrapper.translatesAutoresizingMaskIntoConstraints = false
        addAccountButton.backgroundColor = .systemOrange
        addAccountButton.setTitleColor(.white, for: .normal)
        addAccountButton.layer.cornerRadius = 10
        addAccountButton.translatesAutoresizingMaskIntoConstraints = false
        addAccountButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addAccountButton.addTarget(self, action: #selector(promptAddAppleAccount), for: .touchUpInside)
        btnWrapper.addSubview(addAccountButton)
        
        NSLayoutConstraint.activate([
            addAccountButton.topAnchor.constraint(equalTo: btnWrapper.topAnchor),
            addAccountButton.bottomAnchor.constraint(equalTo: btnWrapper.bottomAnchor),
            addAccountButton.leadingAnchor.constraint(equalTo: btnWrapper.leadingAnchor, constant: 16),
            addAccountButton.trailingAnchor.constraint(equalTo: btnWrapper.trailingAnchor, constant: -16)
        ])
        appleIDView.addArrangedSubview(btnWrapper)
        
        appleTableView.delegate = self
        appleTableView.dataSource = self
        appleTableView.backgroundColor = .clear
        appleIDView.addArrangedSubview(appleTableView)
    }
    
    // MARK: - 3. UDID Section
    private func setupUDIDSection() {
        udidView.axis = .vertical
        udidView.spacing = 16
        udidView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(udidView)
        
        NSLayoutConstraint.activate([
            udidView.topAnchor.constraint(equalTo: containerView.topAnchor),
            udidView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            udidView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        udidTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        udidView.addArrangedSubview(udidTitleLabel)
        
        udidLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        udidLabel.textColor = .systemBlue
        udidLabel.numberOfLines = 0
        udidLabel.textAlignment = .center
        udidLabel.backgroundColor = .secondarySystemGroupedBackground
        udidLabel.layer.cornerRadius = 8
        udidLabel.layer.masksToBounds = true
        udidLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
        udidView.addArrangedSubview(udidLabel)
        
        copyUDIDButton.backgroundColor = .systemBlue
        copyUDIDButton.setTitleColor(.white, for: .normal)
        copyUDIDButton.layer.cornerRadius = 10
        copyUDIDButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        copyUDIDButton.addTarget(self, action: #selector(copyUDIDAction), for: .touchUpInside)
        udidView.addArrangedSubview(copyUDIDButton)
        
        editUDIDButton.backgroundColor = .systemGray5
        editUDIDButton.layer.cornerRadius = 10
        editUDIDButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        editUDIDButton.addTarget(self, action: #selector(editUDIDAction), for: .touchUpInside)
        udidView.addArrangedSubview(editUDIDButton)
        
        updateUDIDDisplay()
    }
    
    private func updateUDIDDisplay() {
        udidLabel.text = DeviceInfoHelper.getDeviceUDID()
    }
    
    @objc private func copyUDIDAction() {
        DeviceInfoHelper.copyUDIDToClipboard()
        let alert = UIAlertController(title: L("已复制", "Copied"), message: L("设备 UDID 已成功复制到系统剪贴板！", "UDID copied to clipboard!"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func editUDIDAction() {
        let alert = UIAlertController(
            title: L("修改设备 UDID", "Override Device UDID"),
            message: L("请输入你的官方 40 位或 25 位设备 UDID：", "Enter your official 40-character or 25-character UDID:"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.text = DeviceInfoHelper.getDeviceUDID()
        }
        alert.addAction(UIAlertAction(title: L("保存", "Save"), style: .default, handler: { [weak self] _ in
            if let val = alert.textFields?.first?.text, !val.isEmpty {
                DeviceInfoHelper.setCustomUDID(val)
                self?.updateUDIDDisplay()
            }
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func segmentChanged() {
        p12View.isHidden = (segmentedControl.selectedSegmentIndex != 0)
        appleIDView.isHidden = (segmentedControl.selectedSegmentIndex != 1)
        udidView.isHidden = (segmentedControl.selectedSegmentIndex != 2)
    }
    
    // MARK: - P12 Logic
    @objc private func importP12Action() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data", "com.rsa.pkcs-12"], in: .import)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func importProvisionAction() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func verifyP12() {
        guard let p12 = importedP12URL else {
            certStatusLabel.text = L("请先导入 .p12 证书文件。", "Please import a .p12 file first.")
            return
        }
        
        do {
            let info = try ZSignBridge.inspectP12(p12.path, password: p12PasswordField.text ?? "")
            let df = DateFormatter()
            df.dateStyle = .medium
            let expStr = info.expirationDate != nil ? df.string(from: info.expirationDate!) : L("未知", "Unknown")
            
            var remainingDaysText = ""
            if let expDate = info.expirationDate {
                let diff = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day ?? 0
                remainingDaysText = diff > 0 ? "\(diff) " + L("天后到期", "days remaining") : L("已过期", "EXPIRED")
            }
            
            let statusStr = info.isExpired ? L("⚠️ 已过期", "EXPIRED") : L("✓ 有效可用", "ACTIVE")
            certStatusLabel.text = "\(L("证书主题", "Name")): \(info.commonName ?? L("开发者", "Developer"))\n\(L("到期时间", "Expires")): \(expStr) (\(remainingDaysText))\n\(L("状态", "Status")): \(statusStr)"
            certStatusLabel.textColor = info.isExpired ? .systemRed : .systemGreen
        } catch {
            certStatusLabel.text = "\(L("校验失败", "Verification failed")): \(error.localizedDescription)"
            certStatusLabel.textColor = .systemRed
        }
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if url.pathExtension.lowercased() == "p12" {
            self.importedP12URL = url
            importP12Button.setTitle("\(L("已载入", "Loaded")): \(url.lastPathComponent)", for: .normal)
            verifyP12()
        } else if url.pathExtension.lowercased() == "mobileprovision" {
            self.importedProvisionURL = url
            importProvisionButton.setTitle("\(L("已载入", "Loaded")): \(url.lastPathComponent)", for: .normal)
        }
    }
    
    // MARK: - Multi-Apple ID TableView
    private func reloadAppleAccounts() {
        appleAccounts = AppleAccountManager.shared.getAllAccounts()
        appleTableView.reloadData()
    }
    
    @objc private func promptAddAppleAccount() {
        let alert = UIAlertController(
            title: L("添加 Apple ID", "Add Apple ID"),
            message: L("输入 Apple ID 凭据，用于免越狱 7 天免费签名（苹果限制每账号最多 3 个应用）：", "Enter credentials for 7-day on-device signing (Max 3 apps per ID):"),
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = L("Apple ID (邮箱)", "Apple ID (Email)") }
        alert.addTextField { $0.placeholder = L("密码", "Password"); $0.isSecureTextEntry = true }
        alert.addTextField { $0.placeholder = L("双重验证码 (若弹出提示)", "2FA Code (if prompted)") }
        
        alert.addAction(UIAlertAction(title: L("登录并保存", "Sign In"), style: .default, handler: { [weak self] _ in
            guard let email = alert.textFields?[0].text, !email.isEmpty,
                  let pass = alert.textFields?[1].text, !pass.isEmpty else { return }
            let twoFactor = alert.textFields?[2].text
            
            AppleDeveloperService.shared.authenticate(appleID: email, password: pass, twoFactorCode: twoFactor) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let session):
                        let account = AppleAccount(email: email, password: pass, teamID: session.teamID, teamName: session.teamName, isActive: true)
                        AppleAccountManager.shared.addOrUpdateAccount(account)
                        self?.reloadAppleAccounts()
                    case .failure(let err):
                        let errAlert = UIAlertController(title: L("登录失败", "Login Failed"), message: err.localizedDescription, preferredStyle: .alert)
                        errAlert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                        self?.present(errAlert, animated: true)
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return appleAccounts.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "AppleAccCell")
        let acc = appleAccounts[indexPath.row]
        let count = AppleAccountManager.shared.activeAppsCount(for: acc.email)
        let isFull = count >= AppleAccountManager.maxAppsPerAppleID
        
        cell.textLabel?.text = acc.email
        
        let quotaText = isFull ? L("⚠️ 配额已满 (3/3)", "⚠️ Quota: 3/3 Full") : "\(L("配额", "Quota")): \(count)/3 \(L("个应用", "Apps"))"
        let activeText = acc.isActive ? "• [" + L("当前活跃签名账号", "ACTIVE SIGNER") + "]" : "• " + L("点击切换", "Tap to Switch")
        cell.detailTextLabel?.text = "\(L("团队", "Team")): \(acc.teamName ?? acc.teamID ?? L("个人团队", "Personal Team")) • \(quotaText) \(activeText)"
        cell.detailTextLabel?.textColor = isFull ? .systemRed : .secondaryLabel
        cell.accessoryType = acc.isActive ? .checkmark : .detailButton
        return cell
    }
    
    public func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        showAppsForAccount(appleAccounts[indexPath.row])
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let acc = appleAccounts[indexPath.row]
        let count = AppleAccountManager.shared.activeAppsCount(for: acc.email)
        
        let sheet = UIAlertController(
            title: acc.email,
            message: "\(L("当前配额", "Quota")): \(count)/3 " + L("个活跃签名应用", "active apps"),
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: L("设为当前默认签名账号", "Set as Active Signing Account"), style: .default, handler: { [weak self] _ in
            AppleAccountManager.shared.setActiveAccount(id: acc.id)
            self?.reloadAppleAccounts()
        }))
        sheet.addAction(UIAlertAction(title: "\(L("查看已签名应用列表", "View Signed Apps")) (\(count))", style: .default, handler: { [weak self] _ in
            self?.showAppsForAccount(acc)
        }))
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func showAppsForAccount(_ acc: AppleAccount) {
        let signedApps = AppleAccountManager.shared.signedApps(for: acc.email)
        let msg: String
        if signedApps.isEmpty {
            msg = L("当前账号暂无签名的应用。", "No apps currently signed with this Apple ID.")
        } else {
            msg = signedApps.map {
                let exp = $0.isExpired ? L("已过期", "Expired") : "\($0.daysRemaining) " + L("天后到期", "days left")
                return "• \($0.name) (v\($0.version)) - \(exp)"
            }.joined(separator: "\n")
        }
        let alert = UIAlertController(title: "\(acc.email) - " + L("已签应用", "Signed Apps"), message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let acc = appleAccounts[indexPath.row]
            AppleAccountManager.shared.removeAccount(id: acc.id)
            reloadAppleAccounts()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
