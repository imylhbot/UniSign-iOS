import UIKit

public class SettingsViewController: UIViewController {
    
    private let anisetteField = UITextField()
    private let portField = UITextField()
    private let clearCacheButton = UIButton(type: .system)
    private let cacheSizeLabel = UILabel()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        updateCacheSize()
    }
    
    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // 1. Anisette Server
        let anisetteTitle = UILabel()
        anisetteTitle.text = "Anisette Server (for Apple ID 2FA / GrandSlam)"
        anisetteTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(anisetteTitle)
        
        anisetteField.text = AnisetteClient.shared.serverURL.absoluteString
        anisetteField.borderStyle = .roundedRect
        anisetteField.autocapitalizationType = .none
        stack.addArrangedSubview(anisetteField)
        
        // 2. Local OTA Server Port
        let portTitle = UILabel()
        portTitle.text = "Local Web Server Port (itms-services OTA)"
        portTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(portTitle)
        
        portField.text = "\(LocalInstallServer.shared.port)"
        portField.borderStyle = .roundedRect
        portField.keyboardType = .numberPad
        stack.addArrangedSubview(portField)
        
        // 3. Clear Cache
        let cacheTitle = UILabel()
        cacheTitle.text = "Storage & Sandbox Cache"
        cacheTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(cacheTitle)
        
        cacheSizeLabel.text = "Cache Size: Calculating..."
        cacheSizeLabel.font = .systemFont(ofSize: 13)
        cacheSizeLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(cacheSizeLabel)
        
        clearCacheButton.setTitle("Clear Temporary & Working Files", for: .normal)
        clearCacheButton.backgroundColor = .systemRed
        clearCacheButton.setTitleColor(.white, for: .normal)
        clearCacheButton.layer.cornerRadius = 10
        clearCacheButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        clearCacheButton.addTarget(self, action: #selector(clearCache), for: .touchUpInside)
        stack.addArrangedSubview(clearCacheButton)
        
        // 4. Save Settings Button
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save Settings", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        saveButton.addTarget(self, action: #selector(saveSettings), for: .touchUpInside)
        stack.addArrangedSubview(saveButton)
    }
    
    @objc private func saveSettings() {
        if let urlStr = anisetteField.text, let url = URL(string: urlStr) {
            AnisetteClient.shared.serverURL = url
        }
        if let portStr = portField.text, let portVal = UInt16(portStr) {
            LocalInstallServer.shared.port = portVal
        }
        
        let alert = UIAlertController(title: "Settings Saved", message: "Configuration parameters have been updated.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func clearCache() {
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        updateCacheSize()
        
        let alert = UIAlertController(title: "Cache Cleared", message: "All temporary working files have been purged.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateCacheSize() {
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(atPath: tempDir.path) {
            var totalSize: UInt64 = 0
            for file in files {
                let path = tempDir.appendingPathComponent(file).path
                if let attr = try? FileManager.default.attributesOfItem(atPath: path) {
                    totalSize += attr[.size] as? UInt64 ?? 0
                }
            }
            let mb = Double(totalSize) / (1024.0 * 1024.0)
            cacheSizeLabel.text = String(format: "Cache Size: %.2f MB", mb)
        } else {
            cacheSizeLabel.text = "Cache Size: 0 MB"
        }
    }
}
