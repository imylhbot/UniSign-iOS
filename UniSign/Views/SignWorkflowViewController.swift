import UIKit

public class SignWorkflowViewController: UIViewController, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    // Selected files
    private var selectedIPAURL: URL?
    private var selectedP12URL: URL?
    private var selectedProvisionURL: URL?
    private var selectedIconImage: UIImage?
    private var dylibsToInject: [URL] = []
    private var dylibsToRemove: [String] = []
    
    // Form fields
    private let ipaButton = UIButton(type: .system)
    private let bundleIdField = UITextField()
    private let nameField = UITextField()
    private let versionField = UITextField()
    private let minOSField = UITextField()
    private let fileSharingSwitch = UISwitch()
    private let docInPlaceSwitch = UISwitch()
    private let iconPreview = UIImageView()
    private let dylibLabel = UILabel()
    
    // Actions & Progress
    private let signButton = UIButton(type: .system)
    private let installButton = UIButton(type: .system)
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let statusLabel = UILabel()
    private let logTextView = UITextView()
    
    private var signedIPAURL: URL?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "IPA Sign & Customize"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 16
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // 1. File Selection Section
        addSectionHeader("1. Source IPA")
        ipaButton.setTitle("Select IPA File from Storage", for: .normal)
        ipaButton.backgroundColor = .systemBlue
        ipaButton.setTitleColor(.white, for: .normal)
        ipaButton.layer.cornerRadius = 10
        ipaButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        ipaButton.addTarget(self, action: #selector(selectIPAFile), for: .touchUpInside)
        contentView.addArrangedSubview(ipaButton)
        
        // 2. Customization Section
        addSectionHeader("2. Bundle & Metadata Customization")
        bundleIdField.placeholder = "New Bundle Identifier (e.g. com.mod.app)"
        bundleIdField.borderStyle = .roundedRect
        contentView.addArrangedSubview(bundleIdField)
        
        nameField.placeholder = "Display Name (e.g. My Modded App)"
        nameField.borderStyle = .roundedRect
        contentView.addArrangedSubview(nameField)
        
        let versionStack = UIStackView()
        versionStack.axis = .horizontal
        versionStack.spacing = 10
        versionStack.distribution = .fillEqually
        versionField.placeholder = "Version (e.g. 2.1.0)"
        versionField.borderStyle = .roundedRect
        minOSField.placeholder = "Min OS (e.g. 13.0)"
        minOSField.borderStyle = .roundedRect
        versionStack.addArrangedSubview(versionField)
        versionStack.addArrangedSubview(minOSField)
        contentView.addArrangedSubview(versionStack)
        
        // 3. Permissions Section
        addSectionHeader("3. File Access & Storage Sharing")
        let switchRow1 = makeSwitchRow(title: "Enable File Sharing (UIFileSharing)", switchView: fileSharingSwitch)
        let switchRow2 = makeSwitchRow(title: "Open Documents In Place", switchView: docInPlaceSwitch)
        fileSharingSwitch.isOn = true
        docInPlaceSwitch.isOn = true
        contentView.addArrangedSubview(switchRow1)
        contentView.addArrangedSubview(switchRow2)
        
        // 4. App Icon Replacement
        addSectionHeader("4. App Icon Replacement")
        let iconStack = UIStackView()
        iconStack.axis = .horizontal
        iconStack.spacing = 16
        iconStack.alignment = .center
        
        iconPreview.backgroundColor = .secondarySystemBackground
        iconPreview.layer.cornerRadius = 14
        iconPreview.clipsToBounds = true
        iconPreview.contentMode = .scaleAspectFill
        iconPreview.image = UIImage(systemName: "app.dashed")
        iconPreview.tintColor = .secondaryLabel
        iconPreview.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconPreview.heightAnchor.constraint(equalToConstant: 64).isActive = true
        
        let changeIconButton = UIButton(type: .system)
        changeIconButton.setTitle("Choose Icon from Photos", for: .normal)
        changeIconButton.addTarget(self, action: #selector(chooseIcon), for: .touchUpInside)
        
        iconStack.addArrangedSubview(iconPreview)
        iconStack.addArrangedSubview(changeIconButton)
        contentView.addArrangedSubview(iconStack)
        
        // 5. Dylib Plugins Injection & Removal
        addSectionHeader("5. Dylib / Tweak Plugins")
        dylibLabel.text = "Injected: 0 dylibs | Removed: 0"
        dylibLabel.font = .systemFont(ofSize: 13, weight: .regular)
        dylibLabel.textColor = .secondaryLabel
        contentView.addArrangedSubview(dylibLabel)
        
        let dylibBtnStack = UIStackView()
        dylibBtnStack.axis = .horizontal
        dylibBtnStack.spacing = 10
        dylibBtnStack.distribution = .fillEqually
        
        let addDylibBtn = UIButton(type: .system)
        addDylibBtn.setTitle("+ Inject Dylib", for: .normal)
        addDylibBtn.backgroundColor = .systemGray5
        addDylibBtn.layer.cornerRadius = 8
        addDylibBtn.addTarget(self, action: #selector(injectDylibPicker), for: .touchUpInside)
        
        let removeDylibBtn = UIButton(type: .system)
        removeDylibBtn.setTitle("- Remove Dylib", for: .normal)
        removeDylibBtn.backgroundColor = .systemGray5
        removeDylibBtn.layer.cornerRadius = 8
        removeDylibBtn.addTarget(self, action: #selector(promptRemoveDylib), for: .touchUpInside)
        
        dylibBtnStack.addArrangedSubview(addDylibBtn)
        dylibBtnStack.addArrangedSubview(removeDylibBtn)
        contentView.addArrangedSubview(dylibBtnStack)
        
        // 6. Action Buttons & Progress
        addSectionHeader("6. Signing & Build")
        signButton.setTitle("Start Signing IPA", for: .normal)
        signButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        signButton.backgroundColor = .systemGreen
        signButton.setTitleColor(.white, for: .normal)
        signButton.layer.cornerRadius = 12
        signButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        signButton.addTarget(self, action: #selector(startSigning), for: .touchUpInside)
        contentView.addArrangedSubview(signButton)
        
        progressBar.progress = 0.0
        progressBar.isHidden = true
        contentView.addArrangedSubview(progressBar)
        
        statusLabel.text = "Ready to customize and sign."
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        contentView.addArrangedSubview(statusLabel)
        
        installButton.setTitle("🚀 Install Signed App Locally", for: .normal)
        installButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        installButton.backgroundColor = .systemIndigo
        installButton.setTitleColor(.white, for: .normal)
        installButton.layer.cornerRadius = 10
        installButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        installButton.isHidden = true
        installButton.addTarget(self, action: #selector(installAppLocally), for: .touchUpInside)
        contentView.addArrangedSubview(installButton)
        
        logTextView.isEditable = false
        logTextView.backgroundColor = .black
        logTextView.textColor = .systemGreen
        logTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.layer.cornerRadius = 8
        logTextView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        logTextView.text = "[UniSign Engine initialized]\nWaiting for IPA selection...\n"
        contentView.addArrangedSubview(logTextView)
    }
    
    private func addSectionHeader(_ title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        contentView.addArrangedSubview(label)
    }
    
    private func makeSwitchRow(title: String, switchView: UISwitch) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing
        let lbl = UILabel()
        lbl.text = title
        lbl.font = .systemFont(ofSize: 14)
        row.addArrangedSubview(lbl)
        row.addArrangedSubview(switchView)
        return row
    }
    
    // MARK: - Handlers
    
    @objc private func selectIPAFile() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.zip-archive", "com.apple.itunes.ipa", "public.data"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    @objc private func chooseIcon() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
    
    @objc private func injectDylibPicker() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data", "public.item"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }
    
    @objc private func promptRemoveDylib() {
        let alert = UIAlertController(title: "Remove Dylib", message: "Enter the dylib filename or path to strip from Mach-O (e.g. SubstrateLoader.dylib):", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "LibraryName.dylib"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                self?.dylibsToRemove.append(text)
                self?.updateDylibLabel()
            }
        }))
        present(alert, animated: true)
    }
    
    private func updateDylibLabel() {
        dylibLabel.text = "Injected: \(dylibsToInject.count) dylibs | Removed: \(dylibsToRemove.count)"
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        if url.pathExtension.lowercased() == "ipa" || url.pathExtension.lowercased() == "zip" {
            self.selectedIPAURL = url
            self.ipaButton.setTitle("Selected: \(url.lastPathComponent)", for: .normal)
            self.ipaButton.backgroundColor = .systemIndigo
            appendLog("[+] Selected IPA: \(url.lastPathComponent)")
        } else {
            // Injected dylibs
            for u in urls {
                if !dylibsToInject.contains(u) {
                    dylibsToInject.append(u)
                    appendLog("[+] Staged dylib: \(u.lastPathComponent)")
                }
            }
            updateDylibLabel()
        }
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let img = info[.originalImage] as? UIImage {
            self.selectedIconImage = img
            self.iconPreview.image = img
            appendLog("[+] New AppIcon selected")
        }
        picker.dismiss(animated: true)
    }
    
    @objc private func startSigning() {
        guard let ipaURL = selectedIPAURL else {
            showAlert("Please select an IPA file first.")
            return
        }
        
        signButton.isEnabled = false
        progressBar.isHidden = false
        progressBar.progress = 0.0
        statusLabel.text = "Starting signing process..."
        appendLog("[*] Initializing signing pipeline...")
        
        // Prepare configuration
        let options = PlistModifier.CustomizationOptions(
            bundleIdentifier: bundleIdField.text,
            displayName: nameField.text,
            versionString: versionField.text,
            minimumOSVersion: minOSField.text,
            enableFileSharing: fileSharingSwitch.isOn,
            enableDocumentInPlace: docInPlaceSwitch.isOn
        )
        
        // Fallback / standard p12 setup for testing
        let dummyP12 = FileManager.default.temporaryDirectory.appendingPathComponent("dev.p12")
        try? Data([0x30, 0x82]).write(to: dummyP12)
        
        let config = IPAManager.SignConfig(
            ipaURL: ipaURL,
            p12URL: dummyP12,
            p12Password: "",
            provisionURL: nil,
            options: options,
            replacementIcon: selectedIconImage,
            dylibsToInject: dylibsToInject,
            dylibsToRemove: dylibsToRemove
        )
        
        IPAManager.processAndSign(config: config, progress: { [weak self] pct, message in
            DispatchQueue.main.async {
                self?.progressBar.setProgress(Float(pct), animated: true)
                self?.statusLabel.text = message
                self?.appendLog(message)
            }
        }) { [weak self] result in
            DispatchQueue.main.async {
                self?.signButton.isEnabled = true
                switch result {
                case .success(let outputURL):
                    self?.signedIPAURL = outputURL
                    self?.statusLabel.text = "Signed Successfully!"
                    self?.statusLabel.textColor = .systemGreen
                    self?.installButton.isHidden = false
                    self?.appendLog("[✓] Signed output saved at: \(outputURL.path)")
                    self?.showAlert("Signing Complete! You can now install it or export via Share.")
                case .failure(let err):
                    self?.statusLabel.text = "Signing Failed"
                    self?.statusLabel.textColor = .systemRed
                    self?.appendLog("[!] Error: \(err.localizedDescription)")
                    self?.showAlert("Signing Error: \(err.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func installAppLocally() {
        guard let outputURL = signedIPAURL else { return }
        
        let bundleID = bundleIdField.text?.isEmpty == false ? bundleIdField.text! : "com.unisign.app"
        let title = nameField.text?.isEmpty == false ? nameField.text! : "Signed App"
        let version = versionField.text?.isEmpty == false ? versionField.text! : "1.0.0"
        
        LocalInstallServer.shared.startServing(ipaURL: outputURL, bundleID: bundleID, version: version, title: title) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let installURL):
                    self?.appendLog("[*] Triggering itms-services installation: \(installURL.absoluteString)")
                    UIApplication.shared.open(installURL, options: [:], completionHandler: nil)
                case .failure(let err):
                    self?.showAlert("Local Server Error: \(err.localizedDescription)")
                }
            }
        }
    }
    
    private func appendLog(_ message: String) {
        logTextView.text.append("\(message)\n")
        let bottom = NSRange(location: logTextView.text.count - 1, length: 1)
        logTextView.scrollRangeToVisible(bottom)
    }
    
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "UniSign", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
