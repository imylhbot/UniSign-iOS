import UIKit

class LogViewerViewController: UIViewController {
    private let textView = UITextView()
    private let filterSegmented = UISegmentedControl(items: ["全部", "认证", "签名", "续签", "系统"])
    private var allLogs: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "操作流程日志"
        view.backgroundColor = SoulSignTheme.background
        setupNavigation()
        setupUI()
        loadLogs()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewLog),
            name: NSNotification.Name("SoulSignNewLogEntryNotification"),
            object: nil
        )
    }

    private func setupNavigation() {
        let trashBtn = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(clearTapped)
        )
        let copyBtn = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain,
            target: self,
            action: #selector(copyTapped)
        )
        let shareBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareTapped)
        )

        navigationItem.rightBarButtonItems = [shareBtn, copyBtn, trashBtn]
    }

    private func setupUI() {
        filterSegmented.selectedSegmentIndex = 0
        filterSegmented.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        filterSegmented.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterSegmented)

        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.1, alpha: 1.0) : UIColor(white: 0.97, alpha: 1.0)
        }
        textView.layer.cornerRadius = 10
        textView.layer.borderWidth = 1
        textView.layer.borderColor = SoulSignTheme.cardBorder.cgColor
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            filterSegmented.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterSegmented.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterSegmented.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            filterSegmented.heightAnchor.constraint(equalToConstant: 32),

            textView.topAnchor.constraint(equalTo: filterSegmented.bottomAnchor, constant: 8),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    @objc private func handleNewLog() {
        loadLogs()
    }

    @objc private func filterChanged() {
        applyFilter()
    }

    private func loadLogs() {
        allLogs = AppLogger.shared.getLogs()
        applyFilter()
    }

    private func applyFilter() {
        let selectedIdx = filterSegmented.selectedSegmentIndex
        let filtered: [String]
        switch selectedIdx {
        case 1:
            filtered = allLogs.filter { $0.contains("认证") }
        case 2:
            filtered = allLogs.filter { $0.contains("签名") }
        case 3:
            filtered = allLogs.filter { $0.contains("续签") }
        case 4:
            filtered = allLogs.filter { $0.contains("系统") || $0.contains("服务") }
        default:
            filtered = allLogs
        }

        if filtered.isEmpty {
            textView.text = "暂无匹配的操作日志"
            textView.textColor = .secondaryLabel
        } else {
            textView.text = filtered.joined(separator: "\n\n")
            textView.textColor = .label
            scrollToBottom()
        }
    }

    private func scrollToBottom() {
        if textView.text.count > 0 {
            let location = textView.text.count - 1
            let bottom = NSRange(location: location, length: 1)
            textView.scrollRangeToVisible(bottom)
        }
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(title: "清空日志", message: "确定要清空所有已记录的操作流程日志吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "清空", style: .destructive, handler: { [weak self] _ in
            AppLogger.shared.clearLogs()
            self?.loadLogs()
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func copyTapped() {
        let text = AppLogger.shared.exportLogText()
        guard !text.isEmpty else {
            showAlert("暂无日志可复制")
            return
        }
        UIPasteboard.general.string = text
        showAlert("已成功复制全部日志到剪贴板！")
    }

    @objc private func shareTapped() {
        let text = AppLogger.shared.exportLogText()
        guard !text.isEmpty else {
            showAlert("暂无日志可导出")
            return
        }
        let avc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(avc, animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
