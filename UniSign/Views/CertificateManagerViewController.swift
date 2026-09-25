import UIKit

public class CertificateManagerViewController: UIViewController, UIDocumentPickerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    private let segmentedControl = UISegmentedControl(items: ["P12 Certificates", "Apple ID Center", "Device UDID"])
    private let containerView = UIView()
    
    // P12 Section Views
    private let p12View = UIStackView()
    private let importP12Button = UIButton(type: .system)
    private let importProvisionButton = UIButton(type: .system)
    private let p12PasswordField = UITextField()
    private let certStatusLabel = UILabel()
    
    // Apple ID Section Views
    private let appleIDView = UIStackView()
    private let appleTableView = UITableView(frame: .zero, style: .plain)
    private let addAccountButton = UIButton(type: .system)
    
    // UDID Section Views
    private let udidView = UIStackView()
    private let udidLabel = UILabel()
    private let copyUDIDButton = UIButton(type: .system)
    private let editUDIDButton = UIButton(type: .system)
    
    private var importedP12URL: URL?
    private var importedProvisionURL: URL?
    private var appleAccounts: [AppleAccount] = []
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Certificates & UDID"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        reloadAppleAccounts()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadAppleAccounts()
        updateUDIDDisplay()
    }
    
    private func setupUI() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        setupP12Section()
        setupAppleIDSection()
        setupUDIDSection()
        segmentChanged()
    }
    
    // MARK: - 1. P12 Section
    private func setupP12Section() {
        p12View.axis = .vertical
        p12View.spacing = 16
        p12View.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(p12View)
        
        NSLayoutConstraint.activate([
            p12View.topAnchor.constraint(equalTo: containerView.topAnchor),
            p12View.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            p12View.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        importP12Button.setTitle("1. Import .p12 Certificate", for: .normal)
        importP12Button.backgroundColor = .systemBlue
        importP12Button.setTitleColor(.white, for: .normal)
        importP12Button.layer.cornerRadius = 10
        importP12Button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        importP12Button.addTarget(self, action: #selector(importP12Action), for: .touchUpInside)
        p12View.addArrangedSubview(importP12Button)
        
        p12PasswordField.placeholder = "P12 Password (Leave empty if none)"
        p12PasswordField.isSecureTextEntry = true
        p12PasswordField.borderStyle = .roundedRect
        p12View.addArrangedSubview(p12PasswordField)
        
        importProvisionButton.setTitle("2. Import .mobileprovision Profile", for: .normal)
        importProvisionButton.backgroundColor = .systemTeal
        importProvisionButton.setTitleColor(.white, for: .normal)
        importProvisionButton.layer.cornerRadius = 10
        importProvisionButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        importProvisionButton.addTarget(self, action: #selector(importProvisionAction), for: .touchUpInside)
        p12View.addArrangedSubview(importProvisionButton)
        
        let verifyBtn = UIButton(type: .system)
        verifyBtn.setTitle("Verify & Calculate Validity", for: .normal)
        verifyBtn.backgroundColor = .systemGray5
        verifyBtn.layer.cornerRadius = 8
        verifyBtn.addTarget(self, action: #selector(verifyP12), for: .touchUpInside)
        p12View.addArrangedSubview(verifyBtn)
        
        certStatusLabel.text = "No P12 certificate loaded."
        certStatusLabel.numberOfLines = 0
        certStatusLabel.font = .systemFont(ofSize: 14)
        certStatusLabel.textColor = .secondaryLabel
        p12View.addArrangedSubview(certStatusLabel)
    }
    
    // MARK: - 2. Apple ID Section
    private func setupAppleIDSection() {
        appleIDView.axis = .vertical
        appleIDView.spacing = 12
        appleIDView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(appleIDView)
        
        NSLayoutConstraint.activate([
            appleIDView.topAnchor.constraint(equalTo: containerView.topAnchor),
            appleIDView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            appleIDView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            appleIDView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        addAccountButton.setTitle("+ Add Apple ID Account", for: .normal)
        addAccountButton.backgroundColor = .systemOrange
        addAccountButton.setTitleColor(.white, for: .normal)
        addAccountButton.layer.cornerRadius = 10
        addAccountButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addAccountButton.addTarget(self, action: #selector(promptAddAppleAccount), for: .touchUpInside)
        appleIDView.addArrangedSubview(addAccountButton)
        
        appleTableView.delegate = self
        appleTableView.dataSource = self
        appleTableView.layer.cornerRadius = 10
        appleTableView.backgroundColor = .secondarySystemGroupedBackground
        appleIDView.addArrangedSubview(appleTableView)
    }
    
    // MARK: - 3. UDID Section
    private func setupUDIDSection() {
        udidView.axis = .vertical
        udidView.spacing = 16
        udidView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(udidView)
        
        NSLayoutConstraint.activate([
            udidView.topAnchor.constraint(equalTo: containerView.topAnchor),
            udidView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            udidView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "Device UDID (Unique Device Identifier)"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        udidView.addArrangedSubview(titleLabel)
        
        udidLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        udidLabel.textColor = .systemBlue
        udidLabel.numberOfLines = 0
        udidLabel.textAlignment = .center
        udidLabel.backgroundColor = .secondarySystemGroupedBackground
        udidLabel.layer.cornerRadius = 8
        udidLabel.layer.masksToBounds = true
        udidLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
        udidView.addArrangedSubview(udidLabel)
        
        copyUDIDButton.setTitle("📋 Copy UDID to Clipboard", for: .normal)
        copyUDIDButton.backgroundColor = .systemBlue
        copyUDIDButton.setTitleColor(.white, for: .normal)
        copyUDIDButton.layer.cornerRadius = 10
        copyUDIDButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        copyUDIDButton.addTarget(self, action: #selector(copyUDIDAction), for: .touchUpInside)
        udidView.addArrangedSubview(copyUDIDButton)
        
        editUDIDButton.setTitle("✏️ Customize / Override UDID", for: .normal)
        editUDIDButton.backgroundColor = .systemGray5
        editUDIDButton.layer.cornerRadius = 10
        editUDIDButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        editUDIDButton.addTarget(self, action: #selector(editUDIDAction), for: .touchUpInside)
        udidView.addArrangedSubview(editUDIDButton)
        
        updateUDIDDisplay()
    }
    
    private func updateUDIDDisplay() {
        udidLabel.text = DeviceInfoHelper.getDeviceUDID()
    }
    
    @objc private func copyUDIDAction() {
        DeviceInfoHelper.copyUDIDToClipboard()
        let alert = UIAlertController(title: "Copied", message: "UDID copied to clipboard!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func editUDIDAction() {
        let alert = UIAlertController(title: "Override Device UDID", message: "Enter your official 40-character or 25-character UDID:", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = DeviceInfoHelper.getDeviceUDID()
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            if let val = alert.textFields?.first?.text, !val.isEmpty {
                DeviceInfoHelper.setCustomUDID(val)
                self?.updateUDIDDisplay()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func segmentChanged() {
        p12View.isHidden = (segmentedControl.selectedSegmentIndex != 0)
        appleIDView.isHidden = (segmentedControl.selectedSegmentIndex != 1)
        udidView.isHidden = (segmentedControl.selectedSegmentIndex != 2)
    }
    
    // MARK: - P12 Logic
    @objc private func importP12Action() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data", "com.rsa.pkcs-12"], in: .import)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func importProvisionAction() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func verifyP12() {
        guard let p12 = importedP12URL else {
            certStatusLabel.text = "Please import a .p12 file first."
            return
        }
        
        var error: NSError?
        let info = ZSignBridge.inspectP12(p12.path, password: p12PasswordField.text ?? "", error: &error)
        
        if let info = info {
            let df = DateFormatter()
            df.dateStyle = .medium
            let expStr = info.expirationDate != nil ? df.string(from: info.expirationDate!) : "Unknown"
            
            var remainingDaysText = ""
            if let expDate = info.expirationDate {
                let diff = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day ?? 0
                remainingDaysText = diff > 0 ? "\(diff) days remaining" : "EXPIRED"
            }
            
            certStatusLabel.text = "Valid Certificate:\nName: \(info.commonName ?? "Developer")\nExpires: \(expStr) (\(remainingDaysText))\nStatus: \(info.isExpired ? "EXPIRED" : "ACTIVE")"
            certStatusLabel.textColor = info.isExpired ? .systemRed : .systemGreen
        } else {
            certStatusLabel.text = "Verification failed: \(error?.localizedDescription ?? "Invalid password or format")"
            certStatusLabel.textColor = .systemRed
        }
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if url.pathExtension.lowercased() == "p12" {
            self.importedP12URL = url
            importP12Button.setTitle("Loaded: \(url.lastPathComponent)", for: .normal)
            verifyP12()
        } else if url.pathExtension.lowercased() == "mobileprovision" {
            self.importedProvisionURL = url
            importProvisionButton.setTitle("Loaded: \(url.lastPathComponent)", for: .normal)
        }
    }
    
    // MARK: - Multi-Apple ID TableView
    private func reloadAppleAccounts() {
        appleAccounts = AppleAccountManager.shared.getAllAccounts()
        appleTableView.reloadData()
    }
    
    @objc private func promptAddAppleAccount() {
        let alert = UIAlertController(title: "Add Apple ID", message: "Enter credentials for 7-day on-device signing:", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Apple ID (Email)" }
        alert.addTextField { $0.placeholder = "Password"; $0.isSecureTextEntry = true }
        alert.addTextField { $0.placeholder = "2FA Code (if prompted)" }
        
        alert.addAction(UIAlertAction(title: "Sign In", style: .default, handler: { [weak self] _ in
            guard let email = alert.textFields?[0].text, !email.isEmpty,
                  let pass = alert.textFields?[1].text, !pass.isEmpty else { return }
            let twoFactor = alert.textFields?[2].text
            
            AppleDeveloperService.shared.authenticate(appleID: email, password: pass, twoFactorCode: twoFactor) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let session):
                        let account = AppleAccount(email: email, password: pass, teamID: session.teamID, teamName: session.teamName, isActive: true)
                        AppleAccountManager.shared.addOrUpdateAccount(account)
                        self?.reloadAppleAccounts()
                    case .failure(let err):
                        let errAlert = UIAlertController(title: "Login Failed", message: err.localizedDescription, preferredStyle: .alert)
                        errAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errAlert, animated: true)
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return appleAccounts.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "AppleAccCell")
        let acc = appleAccounts[indexPath.row]
        cell.textLabel?.text = acc.email
        cell.detailTextLabel?.text = "Team: \(acc.teamName ?? acc.teamID ?? "Personal Team") • \(acc.isActive ? "ACTIVE" : "Tap to Switch")"
        cell.accessoryType = acc.isActive ? .checkmark : .none
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let acc = appleAccounts[indexPath.row]
        AppleAccountManager.shared.setActiveAccount(id: acc.id)
        reloadAppleAccounts()
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let acc = appleAccounts[indexPath.row]
            AppleAccountManager.shared.removeAccount(id: acc.id)
            reloadAppleAccounts()
        }
    }
}
