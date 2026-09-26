import UIKit

public class LogViewerViewController: UIViewController {
    
    private let segmentedControl = UISegmentedControl(items: ["全部", "签名", "证书", "安装", "错误"])
    private let textView = UITextView()
    private let bottomToolbar = UIStackView()
    private let copyBtn = UIButton(type: .system)
    private let shareBtn = UIButton(type: .system)
    private let clearBtn = UIButton(type: .system)
    private let statusLabel = UILabel()
    
    private var selectedCategory: LogCategory? = nil
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0)
        setupNavigationBar()
        setupUI()
        loadLogs()
        
        NotificationCenter.default.addObserver(self, selector: #selector(onNewLogReceived(_:)), name: AppLogger.logNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNavigationBar() {
        title = L("诊断与签名日志", "Diagnostic Logs")
        navigationController?.navigationBar.barTintColor = UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0)
        navigationController?.navigationBar.tintColor = .systemGreen
        
        let closeBtn = UIBarButtonItem(title: L("关闭", "Close"), style: .done, target: self, action: #selector(closeAction))
        navigationItem.leftBarButtonItem = closeBtn
        
        let refreshBtn = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refreshAction))
        navigationItem.rightBarButtonItem = refreshBtn
    }
    
    private func setupUI() {
        // Filter segment
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = UIColor(red: 0.18, green: 0.45, blue: 0.32, alpha: 1.0)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.lightGray, .font: UIFont.systemFont(ofSize: 13, weight: .medium)], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .bold)], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        // Text View (Terminal style)
        textView.backgroundColor = UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0)
        textView.textColor = UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 1.0)
        textView.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.isEditable = false
        textView.layer.cornerRadius = 8
        textView.layer.masksToBounds = true
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        // Status label
        statusLabel.font = UIFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Bottom Toolbar
        bottomToolbar.axis = .horizontal
        bottomToolbar.spacing = 10
        bottomToolbar.distribution = .fillEqually
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomToolbar)
        
        // 1. Copy Button
        copyBtn.setTitle("📋 " + L("一键复制全部", "Copy All"), for: .normal)
        copyBtn.backgroundColor = UIColor(red: 0.12, green: 0.48, blue: 0.35, alpha: 1.0)
        copyBtn.setTitleColor(.white, for: .normal)
        copyBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        copyBtn.layer.cornerRadius = 8
        copyBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        copyBtn.addTarget(self, action: #selector(copyAllLogs), for: .touchUpInside)
        bottomToolbar.addArrangedSubview(copyBtn)
        
        // 2. Share Button
        shareBtn.setTitle("📤 " + L("导出日志", "Export"), for: .normal)
        shareBtn.backgroundColor = UIColor(red: 0.18, green: 0.22, blue: 0.30, alpha: 1.0)
        shareBtn.setTitleColor(.white, for: .normal)
        shareBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        shareBtn.layer.cornerRadius = 8
        shareBtn.addTarget(self, action: #selector(shareLogFile), for: .touchUpInside)
        bottomToolbar.addArrangedSubview(shareBtn)
        
        // 3. Clear Button
        clearBtn.setTitle("🗑️ " + L("清空", "Clear"), for: .normal)
        clearBtn.backgroundColor = UIColor(red: 0.25, green: 0.15, blue: 0.18, alpha: 1.0)
        clearBtn.setTitleColor(.systemRed, for: .normal)
        clearBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        clearBtn.layer.cornerRadius = 8
        clearBtn.addTarget(self, action: #selector(clearLogsConfirm), for: .touchUpInside)
        bottomToolbar.addArrangedSubview(clearBtn)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            textView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            textView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -6),
            
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            statusLabel.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor, constant: -8),
            statusLabel.heightAnchor.constraint(equalToConstant: 16),
            
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func loadLogs() {
        let text = AppLogger.shared.getLogs(category: selectedCategory)
        textView.text = text.isEmpty ? L("暂无此类日志记录", "No logs recorded yet.") : text
        
        let sizeDesc = AppLogger.shared.getLogFileSizeDescription()
        let count = text.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        statusLabel.text = "\(L("日志总计", "Total")): \(count) \(L("行", "lines")) · \(L("文件大小", "File size")): \(sizeDesc)"
        
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        if textView.text.count > 0 {
            let bottom = NSRange(location: textView.text.count - 1, length: 1)
            textView.scrollRangeToVisible(bottom)
        }
    }
    
    @objc private func onNewLogReceived(_ notification: Notification) {
        guard let entry = notification.object as? LogEntry else { return }
        if selectedCategory == nil || entry.category == selectedCategory {
            loadLogs()
        }
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1: selectedCategory = .sign
        case 2: selectedCategory = .cert
        case 3: selectedCategory = .install
        case 4: selectedCategory = .error
        default: selectedCategory = nil
        }
        loadLogs()
    }
    
    @objc private func refreshAction() {
        loadLogs()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    @objc private func closeAction() {
        dismiss(animated: true)
    }
    
    @objc private func copyAllLogs() {
        let fullText = AppLogger.shared.getDiskLogText()
        UIPasteboard.general.string = fullText
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        let alert = UIAlertController(
            title: "📋 " + L("日志已复制到剪贴板！", "Logs Copied!"),
            message: L("您可以直接长按粘贴发送给开发者进行诊断分析。", "Paste and share logs with support for debugging."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func shareLogFile() {
        let fileURL = AppLogger.shared.logFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let alert = UIAlertController(title: L("文件不存在", "File Not Found"), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("好", "OK"), style: .default))
            present(alert, animated: true)
            return
        }
        
        let avc = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popover = avc.popoverPresentationController {
            popover.sourceView = shareBtn
            popover.sourceRect = shareBtn.bounds
        }
        present(avc, animated: true)
    }
    
    @objc private func clearLogsConfirm() {
        let alert = UIAlertController(
            title: L("确认清空日志？", "Clear Logs?"),
            message: L("清空后将无法找回此前的签名记录。", "Previous diagnostic logs will be deleted."),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: L("确认清空", "Clear"), style: .destructive, handler: { [weak self] _ in
            AppLogger.shared.clearLogs()
            self?.loadLogs()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }))
        alert.addAction(UIAlertAction(title: L("取消", "Cancel"), style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = clearBtn
            popover.sourceRect = clearBtn.bounds
        }
        present(alert, animated: true)
    }
}
