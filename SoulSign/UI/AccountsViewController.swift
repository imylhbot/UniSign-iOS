import UIKit

public class AccountsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private var accounts: [AppleAccount] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple ID 账号中心"
        view.backgroundColor = SoulSignTheme.background
        setupNavigation()
        setupTableView()
        loadData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadData),
            name: NSNotification.Name("SoulSignAccountsUpdatedNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loadData),
            name: NSNotification.Name("SoulSignAppLibraryUpdatedNotification"),
            object: nil
        )
    }

    private func setupNavigation() {
        navigationController?.navigationBar.prefersLargeTitles = true

        let addButton = UIBarButtonItem(
            title: "➕ 添加",
            style: .plain,
            target: self,
            action: #selector(addAccountTapped)
        )

        let checkAllButton = UIBarButtonItem(
            title: "🔍 检测全部",
            style: .plain,
            target: self,
            action: #selector(checkAllAccountsTapped)
        )

        navigationItem.rightBarButtonItems = [addButton, checkAllButton]
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AccountCardCell.self, forCellReuseIdentifier: AccountCardCell.identifier)

        refreshControl.attributedTitle = NSAttributedString(string: "下拉一键检测所有账号登录状态...")
        refreshControl.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

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
        accounts = AccountManager.shared.getAllAccounts()
        tableView.reloadData()
    }

    // MARK: - Actions
    @objc private func addAccountTapped() {
        let addVC = AddAccountViewController()
        let nav = UINavigationController(rootViewController: addVC)
        present(nav, animated: true)
    }

    @objc private func checkAllAccountsTapped() {
        guard !accounts.isEmpty else {
            showAlert(title: "提示", message: "尚未添加任何 Apple ID 账号。")
            return
        }

        refreshControl.beginRefreshing()
        SessionValidator.shared.checkAllAccounts { [weak self] _ in
            self?.refreshControl.endRefreshing()
            self?.loadData()
            self?.showAlert(title: "检测完成", message: "所有 Apple ID 账号的登录会话有效性已刷新。")
        }
    }

    @objc private func handlePullToRefresh() {
        SessionValidator.shared.checkAllAccounts { [weak self] _ in
            self?.refreshControl.endRefreshing()
            self?.loadData()
        }
    }

    private func checkSingleAccount(_ account: AppleAccount) {
        let alert = UIAlertController(title: "正在检测", message: "正在向苹果服务器探测 \(account.email) 的登录会话有效性...", preferredStyle: .alert)
        present(alert, animated: true)

        SessionValidator.shared.checkValidity(for: account.email) { [weak self] status, msg in
            alert.dismiss(animated: true) {
                self?.loadData()
                let title = (status == .valid) ? "🟢 账号有效" : "🔴 检测结果"
                self?.showAlert(title: title, message: "账号: \(account.email)\n状态: \(status.title)\n详情: \(msg)")
            }
        }
    }

    private func renewAccountApps(_ account: AppleAccount) {
        let appsCount = AccountManager.shared.activeAppsCount(for: account.email)
        guard appsCount > 0 else {
            showAlert(title: "无需续签", message: "\(account.email) 名下暂无已签名的应用。")
            return
        }

        let progressAlert = UIAlertController(
            title: "⚡ 正在续签",
            message: "准备向苹果申请证书并刷新 7 天生命周期...",
            preferredStyle: .alert
        )
        present(progressAlert, animated: true)

        RenewalService.shared.renewAppsForAccount(
            email: account.email,
            progress: { current, total, name in
                progressAlert.message = "正在续签第 \(current)/\(total) 个应用:\n\(name)..."
            },
            completion: { [weak self] result in
                progressAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let count):
                        self?.showAlert(title: "续签完成", message: "已成功为 \(account.email) 续期 \(count) 个应用 7 天证书！")
                    case .failure(let err):
                        self?.showAlert(title: "续签失败", message: err.localizedDescription)
                    }
                    self?.loadData()
                }
            }
        )
    }

    private func showMoreActions(for account: AppleAccount) {
        let sheet = UIAlertController(title: account.email, message: "账号操作", preferredStyle: .actionSheet)

        if !account.isActive {
            sheet.addAction(UIAlertAction(title: "⭐ 设为当前活跃签名账号", style: .default, handler: { [weak self] _ in
                AccountManager.shared.setActiveAccount(email: account.email)
                self?.loadData()
            }))
        }

        sheet.addAction(UIAlertAction(title: "🗑️ 删除此账号", style: .destructive, handler: { [weak self] _ in
            let confirm = UIAlertController(title: "确认删除", message: "确定要从本机移除账号 \(account.email) 吗？", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "取消", style: .cancel))
            confirm.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { _ in
                AccountManager.shared.removeAccount(email: account.email)
                self?.loadData()
            }))
            self?.present(confirm, animated: true)
        }))

        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UITableView DataSource & Delegate
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if accounts.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "暂未添加 Apple ID\n点击右上角「➕ 添加」即可绑定账号"
            emptyLabel.numberOfLines = 2
            emptyLabel.textAlignment = .center
            emptyLabel.textColor = .secondaryLabel
            tableView.backgroundView = emptyLabel
        } else {
            tableView.backgroundView = nil
        }
        return accounts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: AccountCardCell.identifier,
            for: indexPath
        ) as? AccountCardCell else {
            return UITableViewCell()
        }

        let acc = accounts[indexPath.row]
        cell.configure(with: acc)
        cell.onCheckValidity = { [weak self] in self?.checkSingleAccount(acc) }
        cell.onRenewApps = { [weak self] in self?.renewAccountApps(acc) }
        cell.onMoreActions = { [weak self] in self?.showMoreActions(for: acc) }
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let acc = accounts[indexPath.row]
        AccountManager.shared.setActiveAccount(email: acc.email)
        loadData()
    }
}
