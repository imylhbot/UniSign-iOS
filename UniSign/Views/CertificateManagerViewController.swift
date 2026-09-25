import UIKit

public class CertificateManagerViewController: UIViewController, UIDocumentPickerDelegate {
    
    private let segmentedControl = UISegmentedControl(items: ["P12 Certificates", "Apple ID Signer"])
    private let containerView = UIView()
    
    // P12 Section Views
    private let p12View = UIStackView()
    private let importP12Button = UIButton(type: .system)
    private let importProvisionButton = UIButton(type: .system)
    private let p12PasswordField = UITextField()
    private let certStatusLabel = UILabel()
    
    // Apple ID Section Views
    private let appleIDView = UIStackView()
    private let appleEmailField = UITextField()
    private let applePasswordField = UITextField()
    private let twoFactorField = UITextField()
    private let loginAppleButton = UIButton(type: .system)
    private let appleStatusLabel = UILabel()
    
    private var importedP12URL: URL?
    private var importedProvisionURL: URL?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Certificates & Accounts"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }
    
    private func setupUI() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        setupP12Section()
        setupAppleIDSection()
        segmentChanged()
    }
    
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
        verifyBtn.setTitle("Verify Certificate", for: .normal)
        verifyBtn.backgroundColor = .systemGray5
        verifyBtn.layer.cornerRadius = 8
        verifyBtn.addTarget(self, action: #selector(verifyP12), for: .touchUpInside)
        p12View.addArrangedSubview(verifyBtn)
        
        certStatusLabel.text = "No P12 certificate loaded."
        certStatusLabel.numberOfLines = 0
        certStatusLabel.font = .systemFont(ofSize: 13)
        certStatusLabel.textColor = .secondaryLabel
        p12View.addArrangedSubview(certStatusLabel)
    }
    
    private func setupAppleIDSection() {
        appleIDView.axis = .vertical
        appleIDView.spacing = 14
        appleIDView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(appleIDView)
        
        NSLayoutConstraint.activate([
            appleIDView.topAnchor.constraint(equalTo: containerView.topAnchor),
            appleIDView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            appleIDView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        let tipLabel = UILabel()
        tipLabel.text = "Sign using your Apple ID (Free 7-Day Developer Certificate). No computer required."
        tipLabel.font = .systemFont(ofSize: 13)
        tipLabel.textColor = .secondaryLabel
        tipLabel.numberOfLines = 0
        appleIDView.addArrangedSubview(tipLabel)
        
        appleEmailField.placeholder = "Apple ID (Email)"
        appleEmailField.keyboardType = .emailAddress
        appleEmailField.autocapitalizationType = .none
        appleEmailField.borderStyle = .roundedRect
        appleIDView.addArrangedSubview(appleEmailField)
        
        applePasswordField.placeholder = "Apple ID Password"
        applePasswordField.isSecureTextEntry = true
        applePasswordField.borderStyle = .roundedRect
        appleIDView.addArrangedSubview(applePasswordField)
        
        twoFactorField.placeholder = "2FA Verification Code (if prompted)"
        twoFactorField.keyboardType = .numberPad
        twoFactorField.borderStyle = .roundedRect
        appleIDView.addArrangedSubview(twoFactorField)
        
        loginAppleButton.setTitle("Sign in & Generate Profile", for: .normal)
        loginAppleButton.backgroundColor = .systemOrange
        loginAppleButton.setTitleColor(.white, for: .normal)
        loginAppleButton.layer.cornerRadius = 10
        loginAppleButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        loginAppleButton.addTarget(self, action: #selector(authenticateAppleID), for: .touchUpInside)
        appleIDView.addArrangedSubview(loginAppleButton)
        
        appleStatusLabel.text = "Status: Not logged in."
        appleStatusLabel.font = .systemFont(ofSize: 13)
        appleStatusLabel.textColor = .secondaryLabel
        appleStatusLabel.numberOfLines = 0
        appleIDView.addArrangedSubview(appleStatusLabel)
    }
    
    @objc private func segmentChanged() {
        let isP12 = segmentedControl.selectedSegmentIndex == 0
        p12View.isHidden = !isP12
        appleIDView.isHidden = isP12
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
            certStatusLabel.text = "Valid Certificate:\nName: \(info.commonName ?? "Developer")\nExpires: \(expStr)\nStatus: \(info.isExpired ? "EXPIRED" : "Active")"
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
    
    // MARK: - Apple ID Logic
    @objc private func authenticateAppleID() {
        guard let email = appleEmailField.text, !email.isEmpty,
              let password = applePasswordField.text, !password.isEmpty else {
            appleStatusLabel.text = "Please enter Apple ID and password."
            return
        }
        
        appleStatusLabel.text = "Authenticating with Apple GrandSlam..."
        loginAppleButton.isEnabled = false
        
        AppleDeveloperService.shared.authenticate(
            appleID: email,
            password: password,
            twoFactorCode: twoFactorField.text
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.loginAppleButton.isEnabled = true
                switch result {
                case .success(let session):
                    self?.appleStatusLabel.text = "Logged in successfully!\nTeam: \(session.teamName ?? session.teamID ?? "Personal Team")\nReady for 7-day signing."
                    self?.appleStatusLabel.textColor = .systemGreen
                case .failure(let err):
                    self?.appleStatusLabel.text = "Auth Failed: \(err.localizedDescription)"
                    self?.appleStatusLabel.textColor = .systemRed
                }
            }
        }
    }
}
