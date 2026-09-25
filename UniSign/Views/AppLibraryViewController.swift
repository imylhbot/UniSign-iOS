import UIKit

public class AppLibraryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate {
    
    private let segmentedControl = UISegmentedControl(items: ["Unsigned IPAs", "Signed Apps", "Dylibs"])
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    
    private var unsignedIPAs: [URL] = []
    private var signedApps: [SignedAppRecord] = []
    private var dylibs: [URL] = []
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "App & File Library"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        refreshData()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }
    
    private func setupUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(importNewItem))
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        view.addSubview(tableView)
        
        emptyLabel.text = "No files found.\nTap '+' above to import from Files app."
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func refreshData() {
        unsignedIPAs = AppLibraryManager.shared.getUnsignedIPAs()
        signedApps = AppLibraryManager.shared.getSignedApps()
        dylibs = AppLibraryManager.shared.getImportedDylibs()
        
        let count: Int
        switch segmentedControl.selectedSegmentIndex {
        case 0: count = unsignedIPAs.count
        case 1: count = signedApps.count
        case 2: count = dylibs.count
        default: count = 0
        }
        emptyLabel.isHidden = count > 0
        tableView.reloadData()
    }
    
    @objc private func segmentChanged() {
        refreshData()
    }
    
    @objc private func importNewItem() {
        let picker: UIDocumentPickerViewController
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            // Import IPA
            picker = UIDocumentPickerViewController(documentTypes: ["com.apple.itunes.ipa", "public.zip-archive"], in: .import)
        case 1:
            // Import signed IPA
            picker = UIDocumentPickerViewController(documentTypes: ["com.apple.itunes.ipa", "public.zip-archive"], in: .import)
        default:
            // Import Dylib
            picker = UIDocumentPickerViewController(documentTypes: ["public.data", "public.item"], in: .import)
        }
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            if segmentedControl.selectedSegmentIndex == 2 || url.pathExtension.lowercased() == "dylib" {
                _ = try? AppLibraryManager.shared.importDylib(from: url)
            } else {
                _ = try? AppLibraryManager.shared.importIPA(from: url)
            }
        }
        refreshData()
    }
    
    // MARK: - UITableView DataSource & Delegate
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch segmentedControl.selectedSegmentIndex {
        case 0: return unsignedIPAs.count
        case 1: return signedApps.count
        case 2: return dylibs.count
        default: return 0
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "LibraryCell")
        cell.accessoryType = .disclosureIndicator
        
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            let ipa = unsignedIPAs[indexPath.row]
            cell.imageView?.image = UIImage(systemName: "shippingbox")
            cell.imageView?.tintColor = .systemBlue
            cell.textLabel?.text = ipa.lastPathComponent
            
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: ipa.path)[.size] as? Int64) ?? 0
            let mb = Double(fileSize) / (1024 * 1024)
            cell.detailTextLabel?.text = String(format: "Raw IPA • %.1f MB", mb)
            
        case 1:
            let app = signedApps[indexPath.row]
            cell.imageView?.image = UIImage(systemName: "checkmark.seal.fill")
            cell.imageView?.tintColor = app.isExpired ? .systemRed : .systemGreen
            cell.textLabel?.text = "\(app.name) (v\(app.version))"
            
            let signTag = app.signMethod == "apple_id" ? "Apple ID (\(app.appleIDEmail ?? ""))" : "P12 Certificate"
            let countdown = app.isExpired ? "EXPIRED" : "\(app.daysRemaining) days left"
            cell.detailTextLabel?.text = "\(signTag) • \(countdown)\nBundle: \(app.bundleId)"
            cell.detailTextLabel?.numberOfLines = 2
            
        case 2:
            let dylib = dylibs[indexPath.row]
            cell.imageView?.image = UIImage(systemName: "puzzlepiece.extension")
            cell.imageView?.tintColor = .systemPurple
            cell.textLabel?.text = dylib.lastPathComponent
            cell.detailTextLabel?.text = "Mach-O Dynamic Library (.dylib)"
            
        default:
            break
        }
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            // Action for Unsigned IPA: Launch Sign & Customize
            let ipa = unsignedIPAs[indexPath.row]
            let signVC = SignWorkflowViewController()
            signVC.preselectedIPAURL = ipa
            navigationController?.pushViewController(signVC, animated: true)
            
        case 1:
            // Action for Signed App: Show Options (Install, Renew, Share, Delete)
            let app = signedApps[indexPath.row]
            showSignedAppActionSheet(app: app)
            
        case 2:
            // Action for Dylib: Show info & delete
            let dylib = dylibs[indexPath.row]
            let alert = UIAlertController(title: dylib.lastPathComponent, message: "Imported tweak plugin. Ready to inject into any IPA.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Delete Plugin", style: .destructive, handler: { [weak self] _ in
                AppLibraryManager.shared.deleteDylib(url: dylib)
                self?.refreshData()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
            
        default:
            break
        }
    }
    
    private func showSignedAppActionSheet(app: SignedAppRecord) {
        let sheet = UIAlertController(title: app.name, message: "Bundle ID: \(app.bundleId)\nStatus: \(app.isExpired ? "Expired" : "\(app.daysRemaining) days remaining")", preferredStyle: .actionSheet)
        
        // 1. Install
        sheet.addAction(UIAlertAction(title: "🚀 Install App (OTA)", style: .default, handler: { _ in
            let ipaURL = AppLibraryManager.shared.signedDir.appendingPathComponent(app.fileName)
            LocalInstallServer.shared.startServing(ipaURL: ipaURL, bundleID: app.bundleId, version: app.version, title: app.name) { result in
                DispatchQueue.main.async {
                    if case .success(let url) = result {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
        }))
        
        // 2. 1-Click Renew (if Apple ID)
        if app.signMethod == "apple_id" {
            sheet.addAction(UIAlertAction(title: "🔄 1-Click Renew (7-Day Extension)", style: .default, handler: { [weak self] _ in
                self?.performRenewal(for: app)
            }))
        }
        
        // 3. Share / Export
        sheet.addAction(UIAlertAction(title: "📤 Share / Export IPA", style: .default, handler: { [weak self] _ in
            let ipaURL = AppLibraryManager.shared.signedDir.appendingPathComponent(app.fileName)
            let activity = UIActivityViewController(activityItems: [ipaURL], applicationActivities: nil)
            self?.present(activity, animated: true)
        }))
        
        // 4. Delete
        sheet.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            AppLibraryManager.shared.removeSignedApp(id: app.id)
            self?.refreshData()
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
    
    private func performRenewal(for app: SignedAppRecord) {
        let alert = UIAlertController(title: "Renewing...", message: "Requesting fresh Apple certificate & renewing profile...", preferredStyle: .alert)
        present(alert, animated: true)
        
        RenewalService.shared.renewApp(record: app, progress: { _, msg in
            DispatchQueue.main.async {
                alert.message = msg
            }
        }) { [weak self] result in
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    switch result {
                    case .success(let updated):
                        let successAlert = UIAlertController(title: "Renewed Successfully!", message: "\(updated.name) has been renewed with fresh 7-day validity.", preferredStyle: .alert)
                        successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(successAlert, animated: true)
                        self?.refreshData()
                    case .failure(let err):
                        let errAlert = UIAlertController(title: "Renewal Failed", message: err.localizedDescription, preferredStyle: .alert)
                        errAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errAlert, animated: true)
                    }
                }
            }
        }
    }
}
