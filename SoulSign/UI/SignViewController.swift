import UIKit
import UniformTypeIdentifiers

class SignViewController: UIViewController, UIDocumentPickerDelegate {
    private let ipaCard = UIView()
    private let ipaNameLabel = UILabel()
    private let ipaSizeLabel = UILabel()
    private let selectIPAButton = UIButton(type: .system)

    private let accountCard = UIView()
    private let accountEmailLabel = UILabel()
    private let accountQuotaLabel = UILabel()
    private let accountStatusLabel = UILabel()
    private let changeAccountButton = UIButton(type: .system)

    private let customizeButton = UIButton(type: .system)
    private let signButton = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let statusLabel = UILabel()

    private var selectedIPAURL: URL?
    private var selectedAccount: AppleAccount?
    private var customization = IPAPackager.AppCustomization()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "签名工作�?
        view.backgroundColor = SoulSignTheme.background
        setupNavigation()
        setupUI()
        loadDefaultAccount()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountUpdate),
            name: NSNotification.Name("SoulSignAccountsUpdatedNotification"),
            object: nil
        )
    }

    private func setupNavigation() {
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func setupUI() {
        let scrollView = UIScrollView()
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        // 1. IPA Selection Card
        setupIPACard()
        contentStack.addArrangedSubview(ipaCard)

        // 2. Apple ID Selection Card (with 3-app quota display)
        setupAccountCard()
        contentStack.addArrangedSubview(accountCard)

        // 3. Customization Button
        customizeButton.setTitle("🛠�?深度定制 (修改 Bundle ID / 名称 / 注入插件)", for: .normal)
        customizeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        customizeButton.setTitleColor(SoulSignTheme.primary, for: .normal)
        customizeButton.backgroundColor = SoulSignTheme.primary.withAlphaComponent(0.1)
        customizeButton.layer.cornerRadius = 12
        customizeButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        customizeButton.addTarget(self, action: #selector(customizeTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(customizeButton)

        // 4. Sign Action Button
        SoulSignTheme.stylePrimaryButton(signButton, title: "🚀 开始签名并安装到本�?)
        signButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        signButton.addTarget(self, action: #selector(signTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(signButton)

        // 5. Progress Indicator
        progressView.isHidden = true
        progressView.progressTintColor = SoulSignTheme.primary
        progressView.heightAnchor.constraint(equalToConstant: 6).isActive = true
        contentStack.addArrangedSubview(progressView)

        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        contentStack.addArrangedSubview(statusLabel)
    }

    private func setupIPACard() {
        SoulSignTheme.styleCardView(ipaCard)
        ipaNameLabel.text = "尚未选择 IPA 安装�?
        ipaNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        ipaNameLabel.textColor = .label

        ipaSizeLabel.text = "点击下方按钮从系统「文件」选择或隔空投�?IPA"
        ipaSizeLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        ipaSizeLabel.textColor = SoulSignTheme.secondaryText

        selectIPAButton.setTitle("📁 选取待签 IPA", for: .normal)
        selectIPAButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        selectIPAButton.setTitleColor(.white, for: .normal)
        selectIPAButton.backgroundColor = SoulSignTheme.primary
        selectIPAButton.layer.cornerRadius = 8
        selectIPAButton.addTarget(self, action: #selector(selectIPATapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [ipaNameLabel, ipaSizeLabel, selectIPAButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        ipaCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: ipaCard.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: ipaCard.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: ipaCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: ipaCard.trailingAnchor, constant: -16),
            selectIPAButton.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    private func setupAccountCard() {
        SoulSignTheme.styleCardView(accountCard)

        let titleLabel = UILabel()
        titleLabel.text = "当前签名 Apple ID"
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = SoulSignTheme.secondaryText

        accountEmailLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        accountEmailLabel.textColor = .label

        accountQuotaLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        accountStatusLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)

        changeAccountButton.setTitle("🔄 切换账号", for: .normal)
        changeAccountButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        changeAccountButton.setTitleColor(SoulSignTheme.primary, for: .normal)
        changeAccountButton.addTarget(self, action: #selector(changeAccountTapped), for: .touchUpInside)

        let row1 = UIStackView(arrangedSubviews: [titleLabel, UIView(), changeAccountButton])
        row1.axis = .horizontal

        let row2 = UIStackView(arrangedSubviews: [accountQuotaLabel, UIView(), accountStatusLabel])
        row2.axis = .horizontal

        let stack = UIStackView(arrangedSubviews: [row1, accountEmailLabel, row2])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        accountCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: accountCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: accountCard.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: accountCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: accountCard.trailingAnchor, constant: -16)
        ])
    }

    @objc private func handleAccountUpdate() {
        loadDefaultAccount()
    }

    private func loadDefaultAccount() {
        selectedAccount = AccountManager.shared.getActiveAccount()
        updateAccountCardUI()
    }

    private func updateAccountCardUI() {
        guard let acc = selectedAccount else {
            accountEmailLabel.text = "未登�?Apple ID"
            accountQuotaLabel.text = "请前往「账号中心」添�?
            accountQuotaLabel.textColor = .secondaryLabel
            accountStatusLabel.text = "�?未检�?
            accountStatusLabel.textColor = .secondaryLabel
            return
        }

        accountEmailLabel.text = acc.email
        let used = AccountManager.shared.activeAppsCount(for: acc.email)
        let total = AccountManager.maxQuotaPerAccount
        let remaining = AccountManager.shared.remainingQuota(for: acc.email)

        accountQuotaLabel.text = "配额占用: \(used)/\(total) (可用: \(remaining) �?"
        if used >= total {
            accountQuotaLabel.textColor = SoulSignTheme.danger
        } else {
            accountQuotaLabel.textColor = SoulSignTheme.success
        }

        accountStatusLabel.text = "会话: \(acc.sessionStatus.title)"
        accountStatusLabel.textColor = (acc.sessionStatus == .valid) ? SoulSignTheme.success : SoulSignTheme.danger
    }

    // MARK: - Actions
    @objc private func selectIPATapped() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.init(filenameExtension: "ipa") ?? .data], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        selectedIPAURL = url
        ipaNameLabel.text = url.lastPathComponent
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let mb = Double(size) / (1024.0 * 1024.0)
            ipaSizeLabel.text = String(format: "大小: %.1f MB", mb)
        }
    }

    @objc private func changeAccountTapped() {
        let accounts = AccountManager.shared.getAllAccounts()
        guard !accounts.isEmpty else {
            showAlert(title: "提示", message: "尚未添加任何 Apple ID 账号，请在账号管理中心添加�?)
            return
        }

        let sheet = UIAlertController(title: "选择签名 Apple ID", message: "每个账号最多允许签名激�?3 �?App", preferredStyle: .actionSheet)
        for acc in accounts {
            let used = AccountManager.shared.activeAppsCount(for: acc.email)
            let total = AccountManager.maxQuotaPerAccount
            let title = "\(acc.email) [配额: \(used)/\(total)] (\(acc.sessionStatus.title))"
            sheet.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                self?.selectedAccount = acc
                self?.updateAccountCardUI()
            }))
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    @objc private func customizeTapped() {
        let customizer = AppCustomizerViewController()
        customizer.customization = customization
        customizer.onSave = { [weak self] updated in
            self?.customization = updated
        }
        navigationController?.pushViewController(customizer, animated: true)
    }

    @objc private func signTapped() {
        guard let ipaURL = selectedIPAURL else {
            showAlert(title: "提示", message: "请先选择需要签名的 IPA 文件�?)
            return
        }

        guard let account = selectedAccount else {
            showAlert(title: "提示", message: "请先在账号中心登�?Apple ID�?)
            return
        }

        let targetBundleID = customization.bundleID ?? "com.soulsign.signedapp"

        // 3-App Quota Interception
        if !AccountManager.shared.canSignNewApp(email: account.email, bundleID: targetBundleID) {
            let alert = UIAlertController(
                title: "⚠️ 签名配额已满 (3/3)",
                message: "当前 Apple ID (\(account.email)) 绑定的应用数已达苹果免费配额上限 (3 �?！\n\n请在上方切换到其他有空闲配额�?Apple ID，或前往「应用库」删除不再使用的应用�?,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "切换其他账号", style: .default, handler: { [weak self] _ in
                self?.changeAccountTapped()
            }))
            alert.addAction(UIAlertAction(title: "我知道了", style: .cancel))
            present(alert, animated: true)
            return
        }

        guard let session = AccountManager.shared.getSession(for: account.email) else {
            showAlert(title: "会话失效", message: "当前账号会话已失效，请在账号中心重新登录�?)
            return
        }

        startSigningProcess(ipaURL: ipaURL, session: session, account: account, bundleID: targetBundleID)
    }

    private func startSigningProcess(ipaURL: URL, session: DeveloperSession, account: AppleAccount, bundleID: String) {
        progressView.isHidden = false
        progressView.progress = 0.15
        signButton.isEnabled = false
        statusLabel.text = "1/4: 正在向苹果申请描述文�?.."

        let deviceUDID = DeviceUDIDHelper.getDeviceUDID()

        ProvisioningService.shared.requestSigningMaterials(
            session: session,
            bundleID: bundleID,
            deviceUDID: deviceUDID
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let profileData):
                self.progressView.progress = 0.50
                self.statusLabel.text = "2/4: 正在解包并应用定制参�?.."

                let workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                guard let appBundle = try? IPAPackager.shared.unpackIPA(ipaURL: ipaURL, workDir: workDir) else {
                    self.signingFailed("解包 IPA 失败")
                    return
                }

                IPAPackager.shared.applyCustomizations(appBundleURL: appBundle, customization: self.customization)

                self.progressView.progress = 0.75
                self.statusLabel.text = "3/4: 正在生成 Mach-O 代码签名..."

                CodeSigner.shared.signAppBundle(
                    appBundleURL: appBundle,
                    provisioningProfileData: profileData,
                    bundleID: bundleID,
                    teamID: session.selectedTeamID ?? "DEF0000000"
                ) { signResult in
                    switch signResult {
                    case .success:
                        self.progressView.progress = 1.0
                        self.statusLabel.text = "4/4: 签名完成！正在登记到应用�?.."

                        // Save to library
                        let appRecord = SignedAppRecord(
                            bundleID: bundleID,
                            appName: self.customization.appName ?? ipaURL.deletingPathExtension().lastPathComponent,
                            version: self.customization.version ?? "1.0.0",
                            appleIDEmail: account.email
                        )
                        AppLibraryStore.shared.addOrUpdateRecord(appRecord)

                        self.signingSuccess(bundleID: bundleID)

                    case .failure(let err):
                        self.signingFailed(err.localizedDescription)
                    }
                }

            case .failure(let err):
                self.signingFailed(err.localizedDescription)
            }
        }
    }

    private func signingSuccess(bundleID: String) {
        signButton.isEnabled = true
        progressView.isHidden = true
        statusLabel.text = "�?签名完成�?
        updateAccountCardUI()

        let alert = UIAlertController(
            title: "🎉 签名成功",
            message: "应用已使�?\(selectedAccount?.email ?? "") 签名成功！\n有效�?7 天，可在应用库随时一键续签�?,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func signingFailed(_ reason: String) {
        signButton.isEnabled = true
        progressView.isHidden = true
        statusLabel.text = "�?签名中断"
        showAlert(title: "签名失败", message: reason)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
