import UIKit

public class AppLibraryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate {
    
    private let segmentedControl = UISegmentedControl(items: [
        L("未签名包", "Unsigned IPAs"),
        L("已签名应用", "Signed Apps"),
        L("插件库", "Dylibs")
    ])
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyView = CardView()
    private let emptyIcon = UIImageView()
    private let emptyLabel = UILabel()
    private let emptyImportButton = GradientButton(title: "", style: .primaryCyber, icon: UIImage(systemName: "plus.circle.fill"))
    
    private var unsignedIPAs: [URL] = []
    private var signedApps: [SignedAppRecord] = []
    private var dylibs: [URL] = []
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupUI()
        updateTexts()
        refreshData()
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
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
        tableView.separatorStyle = .singleLine
        view.addSubview(tableView)
        
        setupEmptyView()
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 36),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
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
    }
    
    private func refreshData() {
        unsignedIPAs = AppLibraryManager.shared.getUnsignedIPAs()
        signedApps = AppLibraryManager.shared.getSignedApps()
        dylibs = AppLibraryManager.shared.getImportedDylibs()
        
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
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "LibraryCell")
        cell.backgroundColor = UniSignTheme.cardBackground
        cell.layer.cornerRadius = 14
        cell.layer.masksToBounds = true
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            let ipa = unsignedIPAs[indexPath.row]
            cell.imageView?.image = UIImage(systemName: "shippingbox.circle.fill")
            cell.imageView?.tintColor = .systemBlue
            cell.textLabel?.text = ipa.lastPathComponent
            
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: ipa.path)[.size] as? Int64) ?? 0
            let mb = Double(fileSize) / (1024 * 1024)
            cell.detailTextLabel?.text = String(format: L("未签原生包 • %.1f MB", "Raw IPA • %.1f MB"), mb)
            cell.detailTextLabel?.textColor = .secondaryLabel
            
            let badge = PillBadge(text: L("待签名", "Ready"), style: .info)
            cell.accessoryView = badge
            
        case 1:
            let app = signedApps[indexPath.row]
            cell.imageView?.image = UIImage(systemName: "checkmark.seal.fill")
            cell.imageView?.tintColor = app.isExpired ? .systemRed : .systemGreen
            cell.textLabel?.text = "\(app.name) (v\(app.version))"
            
            let signTag = app.signMethod == "apple_id" ? "Apple ID (\(app.appleIDEmail ?? ""))" : L("P12 商业签名", "P12 Cert")
            cell.detailTextLabel?.text = "\(signTag)\nBundle: \(app.bundleId)"
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.detailTextLabel?.numberOfLines = 2
            
            let badge: PillBadge
            if app.isExpired {
                badge = PillBadge(text: L("已过期", "Expired"), style: .danger)
            } else if app.daysRemaining <= 1 {
                badge = PillBadge(text: L("剩 1 天", "1 Day"), style: .warning)
            } else {
                badge = PillBadge(text: "\(app.daysRemaining) " + L("天有效", "Days"), style: .success)
            }
            cell.accessoryView = badge
            
        case 2:
            let dylib = dylibs[indexPath.row]
            cell.imageView?.image = UIImage(systemName: "puzzlepiece.extension.fill")
            cell.imageView?.tintColor = .systemPurple
            cell.textLabel?.text = dylib.lastPathComponent
            cell.detailTextLabel?.text = L("Mach-O 动态库插件", "Dynamic Library Plugin")
            cell.detailTextLabel?.textColor = .secondaryLabel
            
            let badge = PillBadge(text: L("插件", "Tweak"), style: .info)
            cell.accessoryView = badge
            
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
        
        sheet.addAction(UIAlertAction(title: "✏️ " + L("重命名 IPA 文件", "Rename IPA File"), style: .default, handler: { [weak self] _ in
            self?.promptRenameIPA(ipa)
        }))
        
        sheet.addAction(UIAlertAction(title: "📤 " + L("导出 / 分享 IPA 包", "Share IPA File"), style: .default, handler: { [weak self] _ in
            let avc = UIActivityViewController(activityItems: [ipa], applicationActivities: nil)
            self?.present(avc, animated: true)
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
    
    private func showSignedAppActionSheet(app: SignedAppRecord) {
        let sheet = UIAlertController(
            title: "\(app.name) (v\(app.version))",
            message: "\(L("状态", "Status")): \(app.isExpired ? L("已过期", "Expired") : "\(app.daysRemaining) " + L("天后到期", "days remaining"))\nBundle ID: \(app.bundleId)",
            preferredStyle: .actionSheet
        )
        
        sheet.addAction(UIAlertAction(title: "📲 " + L("本地免数据线安装 (OTA)", "Install Locally (OTA)"), style: .default, handler: { [weak self] _ in
            self?.installApp(app)
        }))
        
        if app.signMethod == "apple_id" {
            sheet.addAction(UIAlertAction(title: "⚡️ " + L("一键重新续签 7 天", "Renew 7 Days"), style: .default, handler: { [weak self] _ in
                self?.renewApp(app)
            }))
        }
        
        sheet.addAction(UIAlertAction(title: "📤 " + L("导出 / 分享 IPA 包", "Share IPA File"), style: .default, handler: { [weak self] _ in
            self?.shareApp(app)
        }))
        
        sheet.addAction(UIAlertAction(title: L("删除已签名应用", "Delete App"), style: .destructive, handler: { [weak self] _ in
            AppLibraryManager.shared.deleteSignedApp(id: app.id)
            self?.refreshData()
        }))
        
        sheet.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func installApp(_ app: SignedAppRecord) {
        let ipaURL = URL(fileURLWithPath: app.filePath)
        guard FileManager.default.fileExists(atPath: ipaURL.path) else {
            let alert = UIAlertController(title: L("错误", "Error"), message: L("找不到对应的 IPA 文件！", "IPA file not found!"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        
        do {
            try LocalInstallServer.shared.start()
            let installURL = LocalInstallServer.shared.generateInstallURL(
                ipaURL: ipaURL,
                bundleID: app.bundleId,
                title: app.name
            )
            UIApplication.shared.open(installURL, options: [:]) { success in
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        } catch {
            let alert = UIAlertController(title: L("安装服务启动失败", "Server Start Failed"), message: error.localizedDescription, preferredStyle: .alert)
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
    
    private func shareApp(_ app: SignedAppRecord) {
        let ipaURL = URL(fileURLWithPath: app.filePath)
        let avc = UIActivityViewController(activityItems: [ipaURL], applicationActivities: nil)
        present(avc, animated: true)
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
