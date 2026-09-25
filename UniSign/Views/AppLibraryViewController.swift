import UIKit

// MARK: - Modern Spacious Card TableView Cell
public class AppLibraryCardCell: UITableViewCell {
    public static let reuseIdentifier = "AppLibraryCardCell"
    
    public let cardContainer = UIView()
    public let iconImageView = UIImageView()
    public let titleLabel = UILabel()
    public let subtitleLabel = UILabel()
    public let detailLabel = UILabel()
    public let badgeView = PillBadge(text: "", style: .info)
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.backgroundColor = UniSignTheme.cardBackground
        cardContainer.layer.cornerRadius = 14
        cardContainer.layer.borderWidth = 1.0
        cardContainer.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
        cardContainer.layer.masksToBounds = true
        contentView.addSubview(cardContainer)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 10
        iconImageView.layer.masksToBounds = true
        cardContainer.addSubview(iconImageView)
        
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(badgeView)
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(textStack)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .label
        textStack.addArrangedSubview(titleLabel)
        
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        textStack.addArrangedSubview(subtitleLabel)
        
        detailLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        textStack.addArrangedSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            iconImageView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 14),
            iconImageView.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.heightAnchor.constraint(equalToConstant: 44),
            
            badgeView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            badgeView.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            
            textStack.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: badgeView.leadingAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -12)
        ])
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - AppLibraryViewController
public class AppLibraryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate, UIDocumentInteractionControllerDelegate {
    
    private let segmentedControl = UISegmentedControl(items: [
        L("未签名包", "Unsigned IPAs"),
        L("已签名应用", "Signed Apps"),
        L("插件库", "Dylibs")
    ])
    
    // Batch Renew Header for Signed Apps Tab
    private let renewHeaderContainer = UIView()
    private let renewAllButton = UIButton(type: .system)
    private let autoRenewTipLabel = UILabel()
    private var renewHeaderHeightConstraint: NSLayoutConstraint!
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = CardView()
    private let emptyIcon = UIImageView()
    private let emptyLabel = UILabel()
    private let emptyImportButton = GradientButton(title: "", style: .primaryCyber, icon: UIImage(systemName: "plus.circle.fill"))
    
    private var unsignedIPAs: [URL] = []
    private var signedApps: [SignedAppRecord] = []
    private var dylibs: [URL] = []
    private var docController: UIDocumentInteractionController?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupUI()
        updateTexts()
        refreshData()
        
        // Auto-check expiry on launch: automatically renews any app expiring within 24h
        checkAndAutoRenewExpiringApps()
        
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }
    
    private func setupUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(importNewItem)
        )
        
        // 1. Segmented Control
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        // 2. Batch Renew Toolbar (Shown only in "已签名应用" tab)
        renewHeaderContainer.translatesAutoresizingMaskIntoConstraints = false
        renewHeaderContainer.backgroundColor = .clear
        view.addSubview(renewHeaderContainer)
        
        let renewStack = UIStackView()
        renewStack.axis = .vertical
        renewStack.spacing = 4
        renewStack.translatesAutoresizingMaskIntoConstraints = false
        renewHeaderContainer.addSubview(renewStack)
        
        renewAllButton.backgroundColor = UIColor(red: 0.11, green: 0.38, blue: 0.28, alpha: 1.0)
        renewAllButton.setTitleColor(.white, for: .normal)
        renewAllButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        renewAllButton.layer.cornerRadius = 10
        renewAllButton.layer.masksToBounds = true
        renewAllButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
        renewAllButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        renewAllButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        renewAllButton.addTarget(self, action: #selector(promptRenewAllApps), for: .touchUpInside)
        renewStack.addArrangedSubview(renewAllButton)
        
        autoRenewTipLabel.font = .systemFont(ofSize: 11, weight: .medium)
        autoRenewTipLabel.textColor = .secondaryLabel
        autoRenewTipLabel.textAlignment = .center
        renewStack.addArrangedSubview(autoRenewTipLabel)
        
        renewHeaderHeightConstraint = renewHeaderContainer.heightAnchor.constraint(equalToConstant: 0)
        renewHeaderHeightConstraint.isActive = true
        renewHeaderContainer.isHidden = true
        
        NSLayoutConstraint.activate([
            renewStack.topAnchor.constraint(equalTo: renewHeaderContainer.topAnchor, constant: 4),
            renewStack.bottomAnchor.constraint(equalTo: renewHeaderContainer.bottomAnchor, constant: -4),
            renewStack.leadingAnchor.constraint(equalTo: renewHeaderContainer.leadingAnchor, constant: 16),
            renewStack.trailingAnchor.constraint(equalTo: renewHeaderContainer.trailingAnchor, constant: -16)
        ])
        
        // 3. TableView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.register(AppLibraryCardCell.self, forCellReuseIdentifier: AppLibraryCardCell.reuseIdentifier)
        view.addSubview(tableView)
        
        setupEmptyView()
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 36),
            
            renewHeaderContainer.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 6),
            renewHeaderContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renewHeaderContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: renewHeaderContainer.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupEmptyView() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)
        
        emptyIcon.image = UIImage(systemName: "shippingbox.fill")
        emptyIcon.tintColor = .systemBlue
        emptyIcon.contentMode = .scaleAspectFit
        emptyIcon.translatesAutoresizingMaskIntoConstraints = false
        emptyIcon.widthAnchor.constraint(equalToConstant: 50).isActive = true
        emptyIcon.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stack.addArrangedSubview(emptyIcon)
        
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 14)
        stack.addArrangedSubview(emptyLabel)
        
        emptyImportButton.translatesAutoresizingMaskIntoConstraints = false
        emptyImportButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        emptyImportButton.widthAnchor.constraint(equalToConstant: 180).isActive = true
        emptyImportButton.addTarget(self, action: #selector(importNewItem), for: .touchUpInside)
        stack.addArrangedSubview(emptyImportButton)
        
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            stack.topAnchor.constraint(equalTo: emptyView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor, constant: -28),
            stack.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -20)
        ])
    }
    
    @objc private func languageDidChange() {
        updateTexts()
        refreshData()
    }
    
    private func updateTexts() {
        title = L("应用资源库", "App Library")
        segmentedControl.setTitle(L("未签名包", "Unsigned IPAs"), forSegmentAt: 0)
        segmentedControl.setTitle(L("已签名应用", "Signed Apps"), forSegmentAt: 1)
        segmentedControl.setTitle(L("插件库", "Dylibs"), forSegmentAt: 2)
        emptyLabel.text = L("当前分类下暂无文件\n点击下方按钮即可直接从「文件」App 导入", "No files found.\nTap below to import files.")
        emptyImportButton.setTitle(L("从文件导入", "Import Files"), for: .normal)
        renewAllButton.setTitle(L("⚡ 一键续签全部已签名应用", "⚡ Renew All Signed Apps"), for: .normal)
        autoRenewTipLabel.text = L("• 每次启动自动检测：距离到期不足 1 天将自动无感续签", "• Auto-checks on launch: apps expiring in 1 day auto-renew")
    }
    
    private func refreshData() {
        unsignedIPAs = AppLibraryManager.shared.getUnsignedIPAs()
        signedApps = AppLibraryManager.shared.getSignedApps()
        dylibs = AppLibraryManager.shared.getImportedDylibs()
        
        let isSignedTab = (segmentedControl.selectedSegmentIndex == 1)
        let appleIDAppsCount = signedApps.filter { $0.signMethod == "apple_id" }.count
        
        // Show batch renew toolbar only when on Signed Apps tab and has items
        if isSignedTab && appleIDAppsCount > 0 {
            renewHeaderContainer.isHidden = false
            renewHeaderHeightConstraint.constant = 64
        } else {
            renewHeaderContainer.isHidden = true
            renewHeaderHeightConstraint.constant = 0
        }
        
        let count: Int
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            count = unsignedIPAs.count
            emptyIcon.image = UIImage(systemName: "shippingbox.fill")
        case 1:
            count = signedApps.count
            emptyIcon.image = UIImage(systemName: "checkmark.seal.fill")
        case 2:
            count = dylibs.count
            emptyIcon.image = UIImage(systemName: "puzzlepiece.extension.fill")
        default:
            count = 0
        }
        emptyView.isHidden = count > 0
        tableView.reloadData()
    }
    
    @objc private func segmentChanged() {
        refreshData()
    }
    
    @objc private func importNewItem() {
        let picker: UIDocumentPickerViewController
        switch segmentedControl.selectedSegmentIndex {
        case 0, 1:
            picker = UIDocumentPickerViewController(documentTypes: ["com.apple.itunes.ipa", "public.zip-archive"], in: .import)
        default:
            picker = UIDocumentPickerViewController(documentTypes: ["public.data", "public.item"], in: .import)
        }
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            if segmentedControl.selectedSegmentIndex == 2 || url.pathExtension.lowercased() == "dylib" {
                _ = try? AppLibraryManager.shared.importDylib(from: url)
            } else {
                _ = try? AppLibraryManager.shared.importIPA(from: url)
            }
        }
        refreshData()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // MARK: - Auto-Renewal on App Launch
    private func checkAndAutoRenewExpiringApps() {
        RenewalService.shared.autoRenewExpiringAppsIfNeeded(withinHours: 24) { [weak self] renewed in
            guard let self = self, !renewed.isEmpty else { return }
            self.refreshData()
            let alert = UIAlertController(
                title: "🎉 " + L("已自动续签应用", "Auto-Renewal Complete"),
                message: String(format: L("检测到 %d 个应用距离到期不足 1 天，已为您自动续订 7 天证书有效期！", "Detected %d app(s) expiring within 1 day. Renewed for 7 days!"), renewed.count),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - Batch Renew All Apps
    @objc private func promptRenewAllApps() {
        let appleApps = signedApps.filter { $0.signMethod == "apple_id" }
        guard !appleApps.isEmpty else {
            let alert = UIAlertController(title: L("提示", "Notice"), message: L("暂无使用 Apple ID 签名的应用需要续签。", "No Apple ID signed apps to renew."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        
        let confirmAlert = UIAlertController(
            title: L("批量续签全部应用", "Batch Renew All Apps"),
            message: String(format: L("检测到 %d 个 Apple ID 签名应用，将依次为它们重新签发 7 天证书有效期，是否开始？", "Found %d signed app(s). Renew all for 7 days?"), appleApps.count),
            preferredStyle: .alert
        )
        confirmAlert.addAction(UIAlertAction(title: L("开始续签", "Renew All"), style: .default, handler: { [weak self] _ in
            self?.executeRenewAllApps()
        }))
        confirmAlert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(confirmAlert, animated: true)
    }
    
    private func executeRenewAllApps() {
        ProgressHUD.shared.show(in: view, title: L("正在批量续签...", "Renewing All..."))
        RenewalService.shared.renewAllSignedApps(progress: { [weak self] current, total, step in
            DispatchQueue.main.async {
                guard let self = self else { return }
                ProgressHUD.shared.update(title: step, detail: "\(current)/\(total)")
            }
        }) { [weak self] renewed, failures in
            DispatchQueue.main.async {
                guard let self = self else { return }
                ProgressHUD.shared.hide()
                self.refreshData()
                
                if failures.isEmpty {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    let alert = UIAlertController(
                        title: "🎉 " + L("批量续签成功", "Renewal Successful"),
                        message: String(format: L("共成功为 %d 个应用续签 7 天有效期！", "Successfully renewed %d app(s)!"), renewed.count),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                    self.present(alert, animated: true)
                } else {
                    let alert = UIAlertController(
                        title: L("续签完成提示", "Renewal Notice"),
                        message: "\(L("成功", "Success")): \(renewed.count)\n\(L("失败原因", "Errors")):\n" + failures.joined(separator: "\n"),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - UITableView DataSource & Delegate
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch segmentedControl.selectedSegmentIndex {
        case 0: return unsignedIPAs.count
        case 1: return signedApps.count
        case 2: return dylibs.count
        default: return 0
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AppLibraryCardCell.reuseIdentifier, for: indexPath) as? AppLibraryCardCell else {
            return UITableViewCell()
        }
        
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            let ipa = unsignedIPAs[indexPath.row]
            cell.iconImageView.image = UIImage(systemName: "shippingbox.circle.fill")
            cell.iconImageView.tintColor = .systemBlue
            cell.titleLabel.text = ipa.lastPathComponent
            
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: ipa.path)[.size] as? Int64) ?? 0
            let mb = Double(fileSize) / (1024 * 1024)
            cell.subtitleLabel.text = String(format: L("未签原生包 • %.1f MB", "Raw IPA • %.1f MB"), mb)
            cell.detailLabel.text = ipa.path
            cell.badgeView.configure(text: L("待签名", "Ready"), style: .info)
            
        case 1:
            let app = signedApps[indexPath.row]
            cell.iconImageView.image = UIImage(systemName: "checkmark.seal.fill")
            cell.iconImageView.tintColor = app.isExpired ? .systemRed : .systemGreen
            cell.titleLabel.text = "\(app.name) (v\(app.version))"
            
            let signTag = app.signMethod == "apple_id" ? "🍏 Apple ID (\(app.appleIDEmail ?? ""))" : L("📜 P12 商业签名", "📜 P12 Cert")
            cell.subtitleLabel.text = signTag
            cell.detailLabel.text = "Bundle ID: \(app.bundleId)"
            
            if app.isExpired {
                cell.badgeView.configure(text: L("已过期", "Expired"), style: .danger)
            } else if app.daysRemaining <= 1 {
                cell.badgeView.configure(text: L("剩 1 天", "1 Day"), style: .warning)
            } else {
                cell.badgeView.configure(text: "\(app.daysRemaining) " + L("天有效", "Days"), style: .success)
            }
            
        case 2:
            let dylib = dylibs[indexPath.row]
            cell.iconImageView.image = UIImage(systemName: "puzzlepiece.extension.fill")
            cell.iconImageView.tintColor = .systemPurple
            cell.titleLabel.text = dylib.lastPathComponent
            cell.subtitleLabel.text = L("Mach-O 动态库插件", "Dynamic Library Plugin")
            cell.detailLabel.text = dylib.path
            cell.badgeView.configure(text: L("插件", "Tweak"), style: .info)
            
        default:
            break
        }
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            let ipa = unsignedIPAs[indexPath.row]
            showUnsignedIPAActionSheet(ipa: ipa)
            
        case 1:
            let app = signedApps[indexPath.row]
            showSignedAppActionSheet(app: app)
            
        case 2:
            let dylib = dylibs[indexPath.row]
            let alert = UIAlertController(
                title: dylib.lastPathComponent,
                message: L("已导入的动态库插件，可在「签名与定制」页面自由选择注入到任何 IPA。", "Imported tweak plugin. Selectable for injection during signing."),
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: L("删除插件", "Delete Plugin"), style: .destructive, handler: { [weak self] _ in
                AppLibraryManager.shared.deleteDylib(url: dylib)
                self?.refreshData()
            }))
            alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
            present(alert, animated: true)
            
        default:
            break
        }
    }
    
    // MARK: - Unsigned IPA Actions
    private func showUnsignedIPAActionSheet(ipa: URL) {
        let sheet = UIAlertController(
            title: ipa.lastPathComponent,
            message: L("请选择对该 IPA 文件的操作：", "Select an action for this IPA:"),
            preferredStyle: .actionSheet
        )
        
        sheet.addAction(UIAlertAction(title: "🚀 " + L("一键签名与安装", "Sign & Sideload"), style: .default, handler: { [weak self] _ in
            let signVC = SignWorkflowViewController()
            signVC.preselectedIPAURL = ipa
            signVC.isModifyOnlyMode = false
            self?.navigationController?.pushViewController(signVC, animated: true)
        }))
        
        sheet.addAction(UIAlertAction(title: "🛠️ " + L("仅修改配置 (不签名 / 免签定制)", "Customize IPA Only (No Sign)"), style: .default, handler: { [weak self] _ in
            let signVC = SignWorkflowViewController()
            signVC.preselectedIPAURL = ipa
            signVC.isModifyOnlyMode = true
            self?.navigationController?.pushViewController(signVC, animated: true)
        }))
        
        sheet.addAction(UIAlertAction(title: "📤 " + L("导出 / 分享 IPA 文件", "Share IPA File"), style: .default, handler: { [weak self] _ in
            self?.shareAppFile(url: ipa)
        }))
        
        sheet.addAction(UIAlertAction(title: "📁 " + L("在其他应用中打开 / 存入「文件」App", "Open in... / Save to Files"), style: .default, handler: { [weak self] _ in
            self?.openInOtherApp(ipa)
        }))
        
        sheet.addAction(UIAlertAction(title: "✏️ " + L("重命名 IPA 文件", "Rename IPA File"), style: .default, handler: { [weak self] _ in
            self?.promptRenameIPA(ipa)
        }))
        
        sheet.addAction(UIAlertAction(title: L("删除此 IPA", "Delete IPA"), style: .destructive, handler: { [weak self] _ in
            AppLibraryManager.shared.deleteUnsignedIPA(url: ipa)
            self?.refreshData()
        }))
        
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func promptRenameIPA(_ ipa: URL) {
        let alert = UIAlertController(
            title: L("重命名 IPA", "Rename IPA"),
            message: L("请输入新的文件名：", "Enter new file name:"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.text = ipa.deletingPathExtension().lastPathComponent
            tf.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: L("确定", "Save"), style: .default, handler: { [weak self] _ in
            guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
            do {
                _ = try AppLibraryManager.shared.renameUnsignedIPA(at: ipa, newName: text)
                self?.refreshData()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                let errAlert = UIAlertController(title: L("重命名失败", "Rename Failed"), message: error.localizedDescription, preferredStyle: .alert)
                errAlert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                self?.present(errAlert, animated: true)
            }
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Signed App Actions (Spacious, Clear, 100% Reliable Options)
    private func showSignedAppActionSheet(app: SignedAppRecord) {
        let sheet = UIAlertController(
            title: "\(app.name) (v\(app.version))",
            message: "\(L("状态", "Status")): \(app.isExpired ? L("已过期", "Expired") : "\(app.daysRemaining) " + L("天后到期", "days remaining"))\nBundle ID: \(app.bundleId)",
            preferredStyle: .actionSheet
        )
        
        let ipaURL = URL(fileURLWithPath: app.filePath)
        
        // 1. 导出 / 分享 IPA 文件 (AirDrop / 存入文件 / 发送给其他人)
        sheet.addAction(UIAlertAction(title: "📤 " + L("导出 / 分享 IPA 文件", "Share IPA File"), style: .default, handler: { [weak self] _ in
            self?.shareAppFile(url: ipaURL)
        }))
        
        // 2. 在其他应用中打开 (支持存入文件、或用 AltStore/轻松签/牛蛙助手安装)
        sheet.addAction(UIAlertAction(title: "📁 " + L("在其他应用中打开 / 存入「文件」App", "Open in... / Save to Files"), style: .default, handler: { [weak self] _ in
            self?.openInOtherApp(ipaURL)
        }))
        
        // 3. 电脑端 USB 助手秒速直装 (推荐，彻底免除 127.0.0.1 困扰)
        sheet.addAction(UIAlertAction(title: "💻 " + L("通过电脑端 USB 助手极速直装 (推荐)", "Install via PC USB Helper"), style: .default, handler: { [weak self] _ in
            self?.showPCHelperGuide()
        }))
        
        // 4. 局域网 Wi-Fi 网页投送下载 (电脑浏览器输入地址直接下载)
        sheet.addAction(UIAlertAction(title: "🌐 " + L("开启局域网 Wi-Fi 网页投送下载", "LAN Wi-Fi Web Transfer"), style: .default, handler: { [weak self] _ in
            self?.startLANWebTransfer(ipaURL: ipaURL, app: app)
        }))
        
        // 5. 巨魔安装 (仅在设备存在巨魔时展示)
        let tsURL = URL(string: "apple-magnifier://")
        if let ts = tsURL, UIApplication.shared.canOpenURL(ts) {
            sheet.addAction(UIAlertAction(title: "⚡ " + L("使用 TrollStore (巨魔) 一键安装", "Install via TrollStore"), style: .default, handler: { [weak self] _ in
                let tsInstall = "apple-magnifier://install?url=\(ipaURL.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                if let url = URL(string: tsInstall) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }))
        }
        
        // 6. 一键重新续签 7 天 (单应用)
        if app.signMethod == "apple_id" {
            sheet.addAction(UIAlertAction(title: "⚡️ " + L("一键重新续签 7 天", "Renew 7 Days"), style: .default, handler: { [weak self] _ in
                self?.renewApp(app)
            }))
        }
        
        // 7. 删除
        sheet.addAction(UIAlertAction(title: L("删除已签名应用", "Delete App"), style: .destructive, handler: { [weak self] _ in
            AppLibraryManager.shared.deleteSignedApp(id: app.id)
            self?.refreshData()
        }))
        
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func shareAppFile(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let alert = UIAlertController(title: L("错误", "Error"), message: L("文件不存在，请重新签名或导入！", "File not found!"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(avc, animated: true)
    }
    
    private func openInOtherApp(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        docController = UIDocumentInteractionController(url: url)
        docController?.delegate = self
        if !docController!.presentOpenInMenu(from: view.bounds, in: view, animated: true) {
            let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            present(avc, animated: true)
        }
    }
    
    private func showPCHelperGuide() {
        let alert = UIAlertController(
            title: "💻 " + L("电脑端 USB 助手秒速直装", "PC USB 1-Click Install"),
            message: L("1. 在电脑上下载 UniSign-Helper-Windows.zip（或运行 run_helper.bat）。\n2. 手机用数据线连接电脑（支持全系 iOS 13~18）。\n3. 将已签名的 IPA 拖入电脑助手，点击「一键直装」，即可 100% 成功秒速安装到手机上，完全免除系统证书验证错误！", "Run UniSign-Helper on PC, connect phone via USB, and 1-click install."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("知道了", "Got it"), style: .default))
        present(alert, animated: true)
    }
    
    private func startLANWebTransfer(ipaURL: URL, app: SignedAppRecord) {
        do {
            try LocalInstallServer.shared.start()
            let shareURL = LocalInstallServer.shared.getShareURL()
            _ = LocalInstallServer.shared.generateInstallURL(ipaURL: ipaURL, bundleID: app.bundleId, title: app.name)
            
            let alert = UIAlertController(
                title: "🌐 " + L("局域网传输已就绪", "LAN Transfer Ready"),
                message: "\(L("请在同 Wi-Fi 下的电脑或其它设备浏览器中打开：", "Open this address in any browser on the same Wi-Fi:\n"))\n\(shareURL)\n\n" + L("网页将提供已签名 IPA 的一键下载，并支持拖入电脑端直接安装！", "Download IPA directly from the webpage."),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L("复制链接", "Copy Link"), style: .default, handler: { _ in
                UIPasteboard.general.string = shareURL
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }))
            alert.addAction(UIAlertAction(title: L("完成", "Done"), style: .cancel))
            present(alert, animated: true)
        } catch {
            let alert = UIAlertController(title: L("服务启动异常", "Server Error"), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
        }
    }
    
    private func renewApp(_ app: SignedAppRecord) {
        ProgressHUD.shared.show(in: view, title: L("正在一键续期...", "Renewing..."), detail: app.name)
        RenewalService.shared.renewSignedApp(app) { [weak self] (result: Result<SignedAppRecord, Error>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                ProgressHUD.shared.hide()
                switch result {
                case .success(let renewed):
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    let alert = UIAlertController(title: L("续期成功", "Renewed"), message: "\(renewed.name) " + L("已成功续期 7 天！", "has been renewed for 7 days!"), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                    self.present(alert, animated: true)
                    self.refreshData()
                case .failure(let err):
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    let alert = UIAlertController(title: L("续期失败", "Renewal Failed"), message: err.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            switch segmentedControl.selectedSegmentIndex {
            case 0:
                AppLibraryManager.shared.deleteUnsignedIPA(url: unsignedIPAs[indexPath.row])
            case 1:
                AppLibraryManager.shared.deleteSignedApp(id: signedApps[indexPath.row].id)
            case 2:
                AppLibraryManager.shared.deleteDylib(url: dylibs[indexPath.row])
            default:
                break
            }
            refreshData()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
