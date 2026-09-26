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
        title = "绛惧悕宸ヤ綔鍙?
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
        customizeButton.setTitle("馃洜锔?娣卞害瀹氬埗 (淇鏀 Bundle ID / 鍚嶇О / 娉ㄥ叆鎻掍欢)", for: .normal)
        customizeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        customizeButton.setTitleColor(SoulSignTheme.primary, for: .normal)
        customizeButton.backgroundColor = SoulSignTheme.primary.withAlphaComponent(0.1)
        customizeButton.layer.cornerRadius = 12
        customizeButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        customizeButton.addTarget(self, action: #selector(customizeTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(customizeButton)

        // 4. Sign Action Button
        SoulSignTheme.stylePrimaryButton(signButton, title: "馃殌 寮濮嬬惧悕骞跺畨瑁呭埌鏈鏈?)
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
        ipaNameLabel.text = "灏氭湭閫夋嫨 IPA 瀹夎呭?
        ipaNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        ipaNameLabel.textColor = .label

        ipaSizeLabel.text = "鐐瑰嚮涓嬫柟鎸夐挳浠庣郴缁熴屾枃浠躲嶉夋嫨鎴栭殧绌烘姇閫?IPA"
        ipaSizeLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        ipaSizeLabel.textColor = SoulSignTheme.secondaryText

        selectIPAButton.setTitle("馃搧 閫夊彇寰呯 IPA", for: .normal)
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
        titleLabel.text = "褰撳墠绛惧悕 Apple ID"
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = SoulSignTheme.secondaryText

        accountEmailLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        accountEmailLabel.textColor = .label

        accountQuotaLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        accountStatusLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)

        changeAccountButton.setTitle("馃攧 鍒囨崲璐﹀彿", for: .normal)
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
            accountEmailLabel.text = "鏈鐧诲?Apple ID"
            accountQuotaLabel.text = "璇峰墠寰銆岃处鍙蜂腑蹇冦嶆坊鍔?
            accountQuotaLabel.textColor = .secondaryLabel
            accountStatusLabel.text = "鈿?鏈妫娴?
            accountStatusLabel.textColor = .secondaryLabel
            return
        }

        accountEmailLabel.text = acc.email
        let used = AccountManager.shared.activeAppsCount(for: acc.email)
        let total = AccountManager.maxQuotaPerAccount
        let remaining = AccountManager.shared.remainingQuota(for: acc.email)

        accountQuotaLabel.text = "閰嶉濆崰鐢: \(used)/\(total) (鍙鐢: \(remaining) 涓?"
        if used >= total {
            accountQuotaLabel.textColor = SoulSignTheme.danger
        } else {
            accountQuotaLabel.textColor = SoulSignTheme.success
        }

        accountStatusLabel.text = "浼氳瘽: \(acc.sessionStatus.title)"
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
            ipaSizeLabel.text = String(format: "澶у皬: %.1f MB", mb)
        }
    }

    @objc private func changeAccountTapped() {
        let accounts = AccountManager.shared.getAllAccounts()
        guard !accounts.isEmpty else {
            showAlert(title: "鎻愮ず", message: "灏氭湭娣诲姞浠讳綍 Apple ID 璐﹀彿锛岃峰湪璐﹀彿绠＄悊涓蹇冩坊鍔犮?)
            return
        }

        let sheet = UIAlertController(title: "閫夋嫨绛惧悕 Apple ID", message: "姣忎釜璐﹀彿鏈澶氬厑璁哥惧悕婵娲?3 涓?App", preferredStyle: .actionSheet)
        for acc in accounts {
            let used = AccountManager.shared.activeAppsCount(for: acc.email)
            let total = AccountManager.maxQuotaPerAccount
            let title = "\(acc.email) [閰嶉: \(used)/\(total)] (\(acc.sessionStatus.title))"
            sheet.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                self?.selectedAccount = acc
                self?.updateAccountCardUI()
            }))
        }
        sheet.addAction(UIAlertAction(title: "鍙栨秷", style: .cancel))
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
            showAlert(title: "鎻愮ず", message: "璇峰厛閫夋嫨闇瑕佺惧悕鐨 IPA 鏂囦欢銆?)
            return
        }

        guard let account = selectedAccount else {
            showAlert(title: "鎻愮ず", message: "璇峰厛鍦ㄨ处鍙蜂腑蹇冪櫥褰?Apple ID銆?)
            return
        }

        let targetBundleID = customization.bundleID ?? "com.soulsign.signedapp"

        // 3-App Quota Interception
        if !AccountManager.shared.canSignNewApp(email: account.email, bundleID: targetBundleID) {
            let alert = UIAlertController(
                title: "鈿狅笍 绛惧悕閰嶉濆凡婊 (3/3)",
                message: "褰撳墠 Apple ID (\(account.email)) 缁戝畾鐨勫簲鐢ㄦ暟宸茶揪鑻规灉鍏嶈垂閰嶉濅笂闄 (3 涓?锛乗n\n璇峰湪涓婃柟鍒囨崲鍒板叾浠栨湁绌洪棽閰嶉濈?Apple ID锛屾垨鍓嶅線銆屽簲鐢ㄥ簱銆嶅垹闄や笉鍐嶄娇鐢ㄧ殑搴旂敤銆?,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "鍒囨崲鍏朵粬璐﹀彿", style: .default, handler: { [weak self] _ in
                self?.changeAccountTapped()
            }))
            alert.addAction(UIAlertAction(title: "鎴戠煡閬撲簡", style: .cancel))
            present(alert, animated: true)
            return
        }

        guard let session = AccountManager.shared.getSession(for: account.email) else {
            showAlert(title: "浼氳瘽澶辨晥", message: "褰撳墠璐﹀彿浼氳瘽宸插け鏁堬紝璇峰湪璐﹀彿涓蹇冮噸鏂扮櫥褰曘?)
            return
        }

        startSigningProcess(ipaURL: ipaURL, session: session, account: account, bundleID: targetBundleID)
    }

    private func startSigningProcess(ipaURL: URL, session: DeveloperSession, account: AppleAccount, bundleID: String) {
        progressView.isHidden = false
        progressView.progress = 0.15
        signButton.isEnabled = false
        statusLabel.text = "1/4: 姝ｅ湪鍚戣嫻鏋滅敵璇锋弿杩版枃浠?.."

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
                self.statusLabel.text = "2/4: 姝ｅ湪瑙ｅ寘骞跺簲鐢ㄥ畾鍒跺弬鏁?.."

                let workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                guard let appBundle = try? IPAPackager.shared.unpackIPA(ipaURL: ipaURL, workDir: workDir) else {
                    self.signingFailed("瑙ｅ寘 IPA 澶辫触")
                    return
                }

                IPAPackager.shared.applyCustomizations(appBundleURL: appBundle, customization: self.customization)

                self.progressView.progress = 0.75
                self.statusLabel.text = "3/4: 姝ｅ湪鐢熸垚 Mach-O 浠ｇ爜绛惧悕..."

                CodeSigner.shared.signAppBundle(
                    appBundleURL: appBundle,
                    provisioningProfileData: profileData,
                    bundleID: bundleID,
                    teamID: session.selectedTeamID ?? "DEF0000000"
                ) { signResult in
                    switch signResult {
                    case .success:
                        self.progressView.progress = 1.0
                        self.statusLabel.text = "4/4: 绛惧悕瀹屾垚锛佹ｅ湪鐧昏板埌搴旂敤搴?.."

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
        statusLabel.text = "鉁?绛惧悕瀹屾垚锛?
        updateAccountCardUI()

        let alert = UIAlertController(
            title: "馃帀 绛惧悕鎴愬姛",
            message: "搴旂敤宸蹭娇鐢?\(selectedAccount?.email ?? "") 绛惧悕鎴愬姛锛乗n鏈夋晥鏈?7 澶╋紝鍙鍦ㄥ簲鐢ㄥ簱闅忔椂涓閿缁绛俱?,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "纭瀹", style: .default))
        present(alert, animated: true)
    }

    private func signingFailed(_ reason: String) {
        signButton.isEnabled = true
        progressView.isHidden = true
        statusLabel.text = "鉂?绛惧悕涓鏂"
        showAlert(title: "绛惧悕澶辫触", message: reason)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "纭瀹", style: .default))
        present(alert, animated: true)
    }
}
