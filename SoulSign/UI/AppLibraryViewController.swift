import UIKit

class AppLibraryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var apps: [SignedAppRecord] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "搴旂敤搴?
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
            title: "鈿?涓閿缁绛惧叏閮?,
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
            showAlert(title: "鎻愮ず", message: "搴旂敤搴撲腑鏆傛棤宸茬惧悕鐨勫簲鐢ㄣ?)
            return
        }

        let progressAlert = UIAlertController(title: "鈿?涓閿缁绛惧叏閮?, message: "姝ｅ湪鍒锋柊鎵鏈夊簲鐢?7 澶╄瘉涔?..", preferredStyle: .alert)
        present(progressAlert, animated: true)

        RenewalService.shared.renewAllApps(
            progress: { cur, total, name in
                progressAlert.message = "姝ｅ湪缁绛剧?\(cur)/\(total) 涓搴旂? \(name)..."
            },
            completion: { [weak self] result in
                progressAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let count):
                        self?.showAlert(title: "缁绛惧畬鎴", message: "鎴愬姛鍒锋柊 \(count) 涓搴旂敤鐨 7 澶╂湁鏁堟湡锛?)
                    case .failure(let err):
                        self?.showAlert(title: "缁绛惧け璐", message: err.localizedDescription)
                    }
                    self?.loadData()
                }
            }
        )
    }

    private func renewSingleApp(_ app: SignedAppRecord) {
        let progressAlert = UIAlertController(title: "鈿?姝ｅ湪缁绛", message: "姝ｅ湪鍒锋柊 \(app.appName) 7 澶╄瘉涔?..", preferredStyle: .alert)
        present(progressAlert, animated: true)

        RenewalService.shared.renewSingleApp(bundleID: app.bundleID) { [weak self] result in
            progressAlert.dismiss(animated: true) {
                switch result {
                case .success:
                    self?.showAlert(title: "缁绛炬垚鍔", message: "\(app.appName) 宸叉垚鍔熺画鏈?7 澶╋紒")
                case .failure(let err):
                    self?.showAlert(title: "缁绛惧け璐", message: err.localizedDescription)
                }
                self?.loadData()
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "纭瀹", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UITableView DataSource & Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if apps.isEmpty {
            let label = UILabel()
            label.text = "鏆傛棤宸茬惧悕搴旂敤\n璇峰湪銆岀惧悕銆嶉〉闈㈠煎?IPA 浣撻獙鏋侀熺惧?
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
        let statusStr = app.isExpired ? "馃敶 宸茶繃鏈? : "馃煝 鍓╀綑 \(days) 澶?
        cell.detailTextLabel?.text = "璐﹀彿: \(app.appleIDEmail) 路 \(app.bundleID) 路 \(statusStr)"
        cell.detailTextLabel?.textColor = app.isExpired ? SoulSignTheme.danger : SoulSignTheme.secondaryText
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let app = apps[indexPath.row]

        let renewAction = UIContextualAction(style: .normal, title: "鈿?缁绛") { [weak self] _, _, completionHandler in
            self?.renewSingleApp(app)
            completionHandler(true)
        }
        renewAction.backgroundColor = SoulSignTheme.success

        let deleteAction = UIContextualAction(style: .destructive, title: "馃棏锔?鍒犻櫎") { [weak self] _, _, completionHandler in
            AppLibraryStore.shared.deleteRecord(bundleID: app.bundleID)
            self?.loadData()
            completionHandler(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction, renewAction])
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let app = apps[indexPath.row]

        let sheet = UIAlertController(title: app.appName, message: "搴旂敤鎿嶄綔", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "鈿?绔嬪嵆鍗曢」缁绛 (7 澶?", style: .default, handler: { [weak self] _ in
            self?.renewSingleApp(app)
        }))
        sheet.addAction(UIAlertAction(title: "馃棏锔?浠庡簲鐢ㄥ簱绉婚櫎", style: .destructive, handler: { [weak self] _ in
            AppLibraryStore.shared.deleteRecord(bundleID: app.bundleID)
            self?.loadData()
        }))
        sheet.addAction(UIAlertAction(title: "鍙栨秷", style: .cancel))
        present(sheet, animated: true)
    }
}
