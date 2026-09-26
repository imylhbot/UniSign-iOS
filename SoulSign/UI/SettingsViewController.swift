import UIKit

public class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
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
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2 // UDID Section
        case 1: return 2 // Anisette & Tools
        case 2: return 2 // About
        default: return 0
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "📱 设备 UDID 硬件凭据"
        case 1: return "⚙️ SideStore 认证设置"
        case 2: return "ℹ️ 关于 SoulSign"
        default: return nil
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "SettingsCell")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)

        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                cell.textLabel?.text = "设备 UDID"
                cell.detailTextLabel?.text = String(DeviceUDIDHelper.getDeviceUDID().prefix(16)) + "..."
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "⚡ Safari 一键获取真实物理 UDID"
                cell.textLabel?.textColor = SoulSignTheme.primary
                cell.accessoryType = .disclosureIndicator
            }

        case 1:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Anisette 远程服务器"
                cell.detailTextLabel?.text = AnisetteProvider.shared.customServerURL ?? "内置本地引擎"
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "🧹 清理应用临时缓存"
                cell.accessoryType = .disclosureIndicator
            }

        case 2:
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

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
            } else {
                DeviceUDIDHelper.openUDIDAcquisitionInSafari()
            }

        case 1:
            if indexPath.row == 0 {
                promptCustomAnisette()
            } else {
                clearCache()
            }

        default:
            break
        }
    }

    private func promptCustomAnisette() {
        let alert = UIAlertController(
            title: "配置 Anisette 服务器",
            message: "默认使用内置本地引擎，如需接入 SideStore 外部 Provision 节点请在此输入：",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "https://anisette.example.com"
            tf.text = AnisetteProvider.shared.customServerURL
        }
        alert.addAction(UIAlertAction(title: "保存", style: .default, handler: { [weak self] _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            AnisetteProvider.shared.customServerURL = text?.isEmpty == false ? text : nil
            self?.tableView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "恢复默认", style: .destructive, handler: { [weak self] _ in
            AnisetteProvider.shared.customServerURL = nil
            self?.tableView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func clearCache() {
        let tmp = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tmp)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let alert = UIAlertController(title: "清理成功", message: "临时解包与签名缓存已全部清除。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
