import UIKit

class AccountsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private var accounts: [AppleAccount] = []
    private let emptyView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple ID 账号中心"
        view.backgroundColor = SoulSignTheme.background
        setupNavigation()
        setupTableView()
        setupEmptyView()
        loadData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dataDidChange),
            name: NSNotification.Name("SoulSignAccountsUpdatedNotification"),
            object: nil
        )
    }

    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.crop.circle.badge.plus"),
            style: .plain,
            target: self,
            action: #selector(addAccountTapped)
        )

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "全部检测",
            style: .plain,
            target: self,
            action: #selector(checkAllTapped)
        )
    }

    private func setupTableView() {
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AccountCardCell.self, forCellReuseIdentifier: AccountCardCell.reuseIdentifier)
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupEmptyView() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)

        let iconView = UIImageView(image: UIImage(systemName: "person.crop.circle.badge.exclamationmark"))
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "暂无绑定的 Apple ID"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let descLabel = UILabel()
        descLabel.text = "点击下方按钮或右上角添加您的 Apple 开发者账号\n推荐使用 Apple 网页快捷登录，免受 GSA 拦截\n每个账号最多支持 3 个应用签名"
        descLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descLabel.textColor = SoulSignTheme.secondaryText
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0

        let addBtn = UIButton(type: .system)
        SoulSignTheme.stylePrimaryButton(addBtn, title: "+ 添加第一个 Apple ID")
        addBtn.addTarget(self, action: #selector(addAccountTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, descLabel, addBtn])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)

        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            stack.topAnchor.constraint(equalTo: emptyView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
            addBtn.heightAnchor.constraint(equalToConstant: 48),
            addBtn.widthAnchor.constraint(equalToConstant: 240)
        ])
    }

    @objc private func dataDidChange() {
        loadData()
    }

    private func loadData() {
        accounts = AccountManager.shared.getAllAccounts()
        emptyView.isHidden = !accounts.isEmpty
        tableView.isHidden = accounts.isEmpty
        if !emptyView.isHidden {
            view.bringSubviewToFront(emptyView)
        }
        tableView.reloadData()
    }

    @objc private func handleRefresh() {
        AppLogger.shared.log("开始批量检测所有账号有效性", category: .portal)
        SessionValidator.shared.validateAllAccounts { [weak self] _ in
            self?.refreshControl.endRefreshing()
            self?.loadData()
        }
    }

    @objc private func addAccountTapped() {
        let addVC = AddAccountViewController()
        let nav = UINavigationController(rootViewController: addVC)
        present(nav, animated: true)
    }

    @objc private func checkAllTapped() {
        guard !accounts.isEmpty else { return }
        let alert = UIAlertController(title: "检测账号有效性", message: "正在检测所有已添加账号的开发者凭据状态...", preferredStyle: .alert)
        present(alert, animated: true)

        AppLogger.shared.log("用户触发全部账号有效性检测", category: .portal)
        SessionValidator.shared.validateAllAccounts { [weak self] _ in
            alert.dismiss(animated: true) {
                self?.loadData()
            }
        }
    }

    private func checkSingleValidity(for account: AppleAccount) {
        AppLogger.shared.log("检测单账号有效性: \(account.email)", category: .portal)
        SessionValidator.shared.validateAccount(account) { [weak self] status, msg in
            let alert = UIAlertController(
                title: "账号有效性检测",
                message: "账号: \(account.email)\n状态: \(status.title)\n\(msg ?? "")",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self?.present(alert, animated: true)
            self?.loadData()
        }
    }

    private func renewAccountApps(for account: AppleAccount) {
        AppLogger.shared.log("开始为账号 \(account.email) 续签应用", category: .renewal)
        RenewalService.shared.renewAppsForAccount(email: account.email, progress: { _, _, _ in }) { [weak self] result in
            let msg: String
            switch result {
            case .success(let count):
                msg = "成功续签了 \(count) 个应用！"
                AppLogger.shared.log("账号 \(account.email) 续签完成，刷新 \(count) 个应用", category: .renewal)
            case .failure(let err):
                msg = "续签提示: \(err.localizedDescription)"
                AppLogger.shared.log("账号 \(account.email) 续签失败: \(err.localizedDescription)", category: .renewal)
            }
            let alert = UIAlertController(title: "一键续签", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self?.present(alert, animated: true)
            self?.loadData()
        }
    }

    private func showMoreActions(for account: AppleAccount) {
        let sheet = UIAlertController(title: account.email, message: "账号管理操作", preferredStyle: .actionSheet)

        if !account.isActive {
            sheet.addAction(UIAlertAction(title: "设为当前活跃签名账号", style: .default) { [weak self] _ in
                AccountManager.shared.setActiveAccount(email: account.email)
                AppLogger.shared.log("切换活跃账号为: \(account.email)", category: .auth)
                self?.loadData()
            })
        }

        sheet.addAction(UIAlertAction(title: "删除此账号", style: .destructive) { [weak self] _ in
            AccountManager.shared.removeAccount(email: account.email)
            AppLogger.shared.log("删除账号: \(account.email)", category: .auth)
            self?.loadData()
        })

        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AccountCardCell.reuseIdentifier, for: indexPath) as! AccountCardCell
        let acc = accounts[indexPath.row]
        cell.configure(with: acc)
        cell.onCheckValidity = { [weak self] in self?.checkSingleValidity(for: acc) }
        cell.onRenewApps = { [weak self] in self?.renewAccountApps(for: acc) }
        cell.onMoreActions = { [weak self] in self?.showMoreActions(for: acc) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let acc = accounts[indexPath.row]
        AccountManager.shared.setActiveAccount(email: acc.email)
        loadData()
    }
}
