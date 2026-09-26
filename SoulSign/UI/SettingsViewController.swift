import UIKit

class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = SoulSignTheme.background
        navigationController?.navigationBar.prefersLargeTitles = true
        setupTableView()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUDIDUpdated),
            name: NSNotification.Name("SoulSignUDIDUpdatedNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUDIDUpdated),
            name: NSNotification.Name("SoulSignNewLogEntryNotification"),
            object: nil
        )
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    @objc private func handleUDIDUpdated() {
        tableView.reloadData()
    }

    // MARK: - UITableView DataSource & Delegate
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // UDID Section
        case 1: return 2 // Anisette & Cache
        case 2: return 2 // Logging Section
        case 3: return 2 // About
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "📱 设备 UDID 硬件凭据"
        case 1: return "⚙️ SideStore 认证设置"
        case 2: return "📋 操作流程日志与调试"
        case 3: return "ℹ️ 关于 SoulSign"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "SettingsCell")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)

        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                cell.textLabel?.text = "设备 UDID"
                cell.detailTextLabel?.text = String(DeviceUDIDHelper.getDeviceUDID().prefix(16)) + "..."
                cell.accessoryType = .disclosureIndicator
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "🌐 访问 UDID 获取网站 (udid.192688.xyz)"
                cell.textLabel?.textColor = SoulSignTheme.primary
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "✏️ 手动输入 / 粘贴真实 UDID"
                cell.textLabel?.textColor = SoulSignTheme.primary
                cell.accessoryType = .disclosureIndicator
            }

        case 1:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Anisette 远程服务器"
                cell.detailTextLabel?.text = AnisetteProvider.shared.serverURL
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "🧹 清理应用临时缓存"
                cell.accessoryType = .disclosureIndicator
            }

        case 2:
            if indexPath.row == 0 {
                cell.textLabel?.text = "开启操作流程日志"
                let toggle = UISwitch()
                toggle.isOn = AppLogger.shared.isLoggingEnabled
                toggle.addTarget(self, action: #selector(loggingToggled(_:)), for: .valueChanged)
                cell.accessoryView = toggle
                cell.selectionStyle = .none
            } else {
                cell.textLabel?.text = "查看运行日志"
                let count = AppLogger.shared.getLogs().count
                cell.detailTextLabel?.text = "已记录 \(count) 条"
                cell.accessoryType = .disclosureIndicator
            }

        case 3:
            if indexPath.row == 0 {
                cell.textLabel?.text = "系统版本要求"
                cell.detailTextLabel?.text = "iOS 15.0 及更高"
            } else {
                cell.textLabel?.text = "版本号"
                cell.detailTextLabel?.text = "SoulSign v2.5.0"
            }

        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                let alert = UIAlertController(title: "本机 UDID", message: DeviceUDIDHelper.getDeviceUDID(), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "复制到剪贴板", style: .default, handler: { _ in
                    DeviceUDIDHelper.copyUDIDToClipboard()
                }))
                alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
                present(alert, animated: true)
            } else if indexPath.row == 1 {
                DeviceUDIDHelper.openUDIDAcquisitionInSafari()
            } else {
                promptManualUDID()
            }

        case 1:
            if indexPath.row == 0 {
                promptCustomAnisette()
            } else {
                clearCache()
            }

        case 2:
            if indexPath.row == 1 {
                let logVC = LogViewerViewController()
                navigationController?.pushViewController(logVC, animated: true)
            }

        default:
            break
        }
    }

    @objc private func loggingToggled(_ sender: UISwitch) {
        AppLogger.shared.isLoggingEnabled = sender.isOn
        AppLogger.shared.log("操作流程日志已\(sender.isOn ? "开启" : "关闭")", category: .general)
    }

    private func promptManualUDID() {
        let alert = UIAlertController(
            title: "手动设置真实物理 UDID",
            message: "若通过网站 (https://udid.192688.xyz/) 获取了 UDID，请直接在此粘贴：",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "25~40 位设备 UDID"
            if let pasteboard = UIPasteboard.general.string, pasteboard.count >= 24 {
                tf.text = pasteboard.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            } else {
                tf.text = DeviceUDIDHelper.getDeviceUDID()
            }
        }
        alert.addAction(UIAlertAction(title: "保存", style: .default, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !text.isEmpty {
                DeviceUDIDHelper.setCustomUDID(text)
                self?.tableView.reloadData()
            }
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func promptCustomAnisette() {
        let alert = UIAlertController(
            title: "配置 Anisette 服务器",
            message: "默认使用 SideStore 官方节点 (\(AnisetteProvider.defaultServerURL))：",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = AnisetteProvider.defaultServerURL
            tf.text = AnisetteProvider.shared.customServerURL
        }
        alert.addAction(UIAlertAction(title: "保存", style: .default, handler: { [weak self] _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            AnisetteProvider.shared.customServerURL = text?.isEmpty == false ? text : nil
            AppLogger.shared.log("更新 Anisette 服务器地址: \(AnisetteProvider.shared.serverURL)", category: .auth)
            self?.tableView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "恢复默认", style: .destructive, handler: { [weak self] _ in
            AnisetteProvider.shared.customServerURL = nil
            AppLogger.shared.log("恢复默认 Anisette 服务器", category: .auth)
            self?.tableView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func clearCache() {
        let tmp = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tmp)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        AppLogger.shared.log("临时缓存已清除", category: .general)

        let alert = UIAlertController(title: "清理成功", message: "临时解包与签名缓存已全部清除。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
