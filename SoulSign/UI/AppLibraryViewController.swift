import UIKit

class AppLibraryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var apps: [SignedAppRecord] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "应用库"
        view.backgroundColor = SoulSignTheme.background
        setupNavigation()
        setupTableView()
        loadData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadData),
            name: NSNotification.Name("SoulSignAppLibraryUpdatedNotification"),
            object: nil
        )
    }

    private func setupNavigation() {
        navigationController?.navigationBar.prefersLargeTitles = true

        let renewAllButton = UIBarButtonItem(
            title: "⚡ 一键续签全部",
            style: .plain,
            target: self,
            action: #selector(renewAllTapped)
        )
        navigationItem.rightBarButtonItem = renewAllButton
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AppCell")

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    @objc private func loadData() {
        apps = AppLibraryStore.shared.getAllRecords()
        tableView.reloadData()
    }

    // MARK: - Actions
    @objc private func renewAllTapped() {
        guard !apps.isEmpty else {
            showAlert(title: "提示", message: "应用库中暂无已签名的应用。")
            return
        }

        let progressAlert = UIAlertController(title: "⚡ 一键续签全部", message: "正在刷新所有应用 7 天证书...", preferredStyle: .alert)
        present(progressAlert, animated: true)

        RenewalService.shared.renewAllApps(
            progress: { cur, total, name in
                progressAlert.message = "正在续签第 \(cur)/\(total) 个应用: \(name)..."
            },
            completion: { [weak self] result in
                progressAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let count):
                        self?.showAlert(title: "续签完成", message: "成功刷新 \(count) 个应用的 7 天有效期！")
                    case .failure(let err):
                        self?.showAlert(title: "续签失败", message: err.localizedDescription)
                    }
                    self?.loadData()
                }
            }
        )
    }

    private func renewSingleApp(_ app: SignedAppRecord) {
        let progressAlert = UIAlertController(title: "⚡ 正在续签", message: "正在刷新 \(app.appName) 7 天证书...", preferredStyle: .alert)
        present(progressAlert, animated: true)

        RenewalService.shared.renewSingleApp(bundleID: app.bundleID) { [weak self] result in
            progressAlert.dismiss(animated: true) {
                switch result {
                case .success:
                    self?.showAlert(title: "续签成功", message: "\(app.appName) 已成功续期 7 天！")
                case .failure(let err):
                    self?.showAlert(title: "续签失败", message: err.localizedDescription)
                }
                self?.loadData()
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UITableView DataSource & Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if apps.isEmpty {
            let label = UILabel()
            label.text = "暂无已签名应用\n请在「签名」页面导入 IPA 体验极速签名"
            label.numberOfLines = 2
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
        return apps.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "AppCell")
        let app = apps[indexPath.row]

        cell.textLabel?.text = app.appName
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)

        let days = app.remainingDays
        let statusStr = app.isExpired ? "🔴 已过期" : "🟢 剩余 \(days) 天"
        cell.detailTextLabel?.text = "账号: \(app.appleIDEmail) · \(app.bundleID) · \(statusStr)"
        cell.detailTextLabel?.textColor = app.isExpired ? SoulSignTheme.danger : SoulSignTheme.secondaryText

        let installBtn = UIButton(type: .system)
        installBtn.setTitle("📲 安装", for: .normal)
        installBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        installBtn.backgroundColor = SoulSignTheme.primary.withAlphaComponent(0.12)
        installBtn.setTitleColor(SoulSignTheme.primary, for: .normal)
        installBtn.layer.cornerRadius = 8
        installBtn.frame = CGRect(x: 0, y: 0, width: 68, height: 32)
        installBtn.tag = indexPath.row
        installBtn.addTarget(self, action: #selector(installButtonTapped(_:)), for: .touchUpInside)
        cell.accessoryView = installBtn

        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let app = apps[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "🗑️ 删除") { [weak self] _, _, completionHandler in
            AppLibraryStore.shared.deleteRecord(bundleID: app.bundleID)
            self?.loadData()
            completionHandler(true)
        }

        let renewAction = UIContextualAction(style: .normal, title: "⚡ 续签") { [weak self] _, _, completionHandler in
            self?.renewSingleApp(app)
            completionHandler(true)
        }
        renewAction.backgroundColor = SoulSignTheme.success

        let installAction = UIContextualAction(style: .normal, title: "📲 安装") { [weak self] _, _, completionHandler in
            self?.installApp(app)
            completionHandler(true)
        }
        installAction.backgroundColor = SoulSignTheme.primary

        return UISwipeActionsConfiguration(actions: [deleteAction, renewAction, installAction])
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let app = apps[indexPath.row]

        let sheet = UIAlertController(title: "【\(app.appName)】应用操作", message: "Bundle ID: \(app.bundleID)\n绑定账号: \(app.appleIDEmail)", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "📲 立即安装到本机", style: .default, handler: { [weak self] _ in
            self?.installApp(app)
        }))
        sheet.addAction(UIAlertAction(title: "📤 导出 / 隔空投送 IPA", style: .default, handler: { [weak self] _ in
            self?.exportApp(app)
        }))
        sheet.addAction(UIAlertAction(title: "⚡ 立即单项续签 (7 天)", style: .default, handler: { [weak self] _ in
            self?.renewSingleApp(app)
        }))
        sheet.addAction(UIAlertAction(title: "🗑️ 从应用库移除", style: .destructive, handler: { [weak self] _ in
            AppLibraryStore.shared.deleteRecord(bundleID: app.bundleID)
            self?.loadData()
        }))
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController, let cell = tableView.cellForRow(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func installButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < apps.count else { return }
        let app = apps[index]
        installApp(app)
    }

    private func installApp(_ app: SignedAppRecord) {
        guard let ipaPath = app.ipaPath, FileManager.default.fileExists(atPath: ipaPath) else {
            showAlert(title: "安装包不存在", message: "未找到应用【\(app.appName)】的 IPA 文件，请在签名工作台重新签名。")
            return
        }
        let url = URL(fileURLWithPath: ipaPath)
        LocalInstallServer.shared.installApp(ipaURL: url, bundleID: app.bundleID, title: app.appName)
    }

    private func exportApp(_ app: SignedAppRecord) {
        guard let ipaPath = app.ipaPath, FileManager.default.fileExists(atPath: ipaPath) else {
            showAlert(title: "安装包不存在", message: "未找到应用【\(app.appName)】的 IPA 文件。")
            return
        }
        let url = URL(fileURLWithPath: ipaPath)
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(activity, animated: true)
    }
}
