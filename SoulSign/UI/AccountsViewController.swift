import UIKit

class AccountsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private var accounts: [AppleAccount] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple ID 璐﹀彿涓蹇"
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
            title: "鉃?娣诲姞",
            style: .plain,
            target: self,
            action: #selector(addAccountTapped)
        )

        let checkAllButton = UIBarButtonItem(
            title: "馃攳 妫娴嬪叏閮?,
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

        refreshControl.attributedTitle = NSAttributedString(string: "涓嬫媺涓閿妫娴嬫墍鏈夎处鍙风櫥褰曠姸鎬?..")
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
            showAlert(title: "鎻愮ず", message: "灏氭湭娣诲姞浠讳綍 Apple ID 璐﹀彿銆?)
            return
        }

        refreshControl.beginRefreshing()
        SessionValidator.shared.checkAllAccounts { [weak self] _ in
            self?.refreshControl.endRefreshing()
            self?.loadData()
            self?.showAlert(title: "妫娴嬪畬鎴?, message: "鎵鏈?Apple ID 璐﹀彿鐨勭櫥褰曚細璇濇湁鏁堟у凡鍒锋柊銆?)
        }
    }

    @objc private func handlePullToRefresh() {
        SessionValidator.shared.checkAllAccounts { [weak self] _ in
            self?.refreshControl.endRefreshing()
            self?.loadData()
        }
    }

    private func checkSingleAccount(_ account: AppleAccount) {
        let alert = UIAlertController(title: "姝ｅ湪妫娴?, message: "姝ｅ湪鍚戣嫻鏋滄湇鍔″櫒鎺㈡祴 \(account.email) 鐨勭櫥褰曚細璇濇湁鏁堟?..", preferredStyle: .alert)
        present(alert, animated: true)

        SessionValidator.shared.checkValidity(for: account.email) { [weak self] status, msg in
            alert.dismiss(animated: true) {
                self?.loadData()
                let title = (status == .valid) ? "馃煝 璐﹀彿鏈夋晥" : "馃敶 妫娴嬬粨鏋?
                self?.showAlert(title: title, message: "璐﹀彿: \(account.email)\n鐘舵? \(status.title)\n璇︽儏: \(msg)")
            }
        }
    }

    private func renewAccountApps(_ account: AppleAccount) {
        let appsCount = AccountManager.shared.activeAppsCount(for: account.email)
        guard appsCount > 0 else {
            showAlert(title: "鏃犻渶缁绛", message: "\(account.email) 鍚嶄笅鏆傛棤宸茬惧悕鐨勫簲鐢ㄣ?)
            return
        }

        let progressAlert = UIAlertController(
            title: "鈿?姝ｅ湪缁绛",
            message: "鍑嗗囧悜鑻规灉鐢宠疯瘉涔﹀苟鍒锋柊 7 澶╃敓鍛藉懆鏈?..",
            preferredStyle: .alert
        )
        present(progressAlert, animated: true)

        RenewalService.shared.renewAppsForAccount(
            email: account.email,
            progress: { current, total, name in
                progressAlert.message = "姝ｅ湪缁绛剧?\(current)/\(total) 涓搴旂?\n\(name)..."
            },
            completion: { [weak self] result in
                progressAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let count):
                        self?.showAlert(title: "缁绛惧畬鎴", message: "宸叉垚鍔熶负 \(account.email) 缁鏈 \(count) 涓搴旂?7 澶╄瘉涔︼紒")
                    case .failure(let err):
                        self?.showAlert(title: "缁绛惧け璐", message: err.localizedDescription)
                    }
                    self?.loadData()
                }
            }
        )
    }

    private func showMoreActions(for account: AppleAccount) {
        let sheet = UIAlertController(title: account.email, message: "璐﹀彿鎿嶄綔", preferredStyle: .actionSheet)

        if !account.isActive {
            sheet.addAction(UIAlertAction(title: "猸?璁句负褰撳墠娲昏穬绛惧悕璐﹀彿", style: .default, handler: { [weak self] _ in
                AccountManager.shared.setActiveAccount(email: account.email)
                self?.loadData()
            }))
        }

        sheet.addAction(UIAlertAction(title: "馃棏锔?鍒犻櫎姝よ处鍙?, style: .destructive, handler: { [weak self] _ in
            let confirm = UIAlertController(title: "纭璁ゅ垹闄", message: "纭瀹氳佷粠鏈鏈虹Щ闄よ处鍙 \(account.email) 鍚楋紵", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "鍙栨秷", style: .cancel))
            confirm.addAction(UIAlertAction(title: "鍒犻櫎", style: .destructive, handler: { _ in
                AccountManager.shared.removeAccount(email: account.email)
                self?.loadData()
            }))
            self?.present(confirm, animated: true)
        }))

        sheet.addAction(UIAlertAction(title: "鍙栨秷", style: .cancel))
        present(sheet, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "纭瀹", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UITableView DataSource & Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if accounts.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "鏆傛湭娣诲姞 Apple ID\n鐐瑰嚮鍙充笂瑙掋屸灂 娣诲姞銆嶅嵆鍙缁戝畾璐﹀?
            emptyLabel.numberOfLines = 2
            emptyLabel.textAlignment = .center
            emptyLabel.textColor = .secondaryLabel
            tableView.backgroundView = emptyLabel
        } else {
            tableView.backgroundView = nil
        }
        return accounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let acc = accounts[indexPath.row]
        AccountManager.shared.setActiveAccount(email: acc.email)
        loadData()
    }
}
