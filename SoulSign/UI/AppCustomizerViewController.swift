import UIKit

class AppCustomizerViewController: UIViewController {
    var customization = IPAPackager.AppCustomization()
    var onSave: ((IPAPackager.AppCustomization) -> Void)?

    private let bundleIDField = UITextField()
    private let appNameField = UITextField()
    private let versionField = UITextField()
    private let minOSField = UITextField()
    private let fileSharingSwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "搴旂敤娣卞害瀹氬埗"
        view.backgroundColor = SoulSignTheme.background
        setupNavigation()
        setupUI()
    }

    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "淇濆瓨",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
    }

    private func setupUI() {
        let container = UIView()
        SoulSignTheme.styleCardView(container)
        view.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        bundleIDField.placeholder = "Bundle Identifier (濡? com.app.signed)"
        bundleIDField.text = customization.bundleID
        styleTextField(bundleIDField)

        appNameField.placeholder = "搴旂敤鏄剧ず鍚嶇О"
        appNameField.text = customization.appName
        styleTextField(appNameField)

        versionField.placeholder = "鐗堟湰鍙?(濡? 1.0.0)"
        versionField.text = customization.version
        styleTextField(versionField)

        minOSField.placeholder = "鏈浣庢敮鎸?iOS 鐗堟湰 (濡? 15.0)"
        minOSField.text = customization.minimumOS
        styleTextField(minOSField)

        let switchLabel = UILabel()
        switchLabel.text = "寮鍚绯荤粺銆屾枃浠躲嶅簲鐢ㄦ矙鐩掍簰閫?
        switchLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)

        fileSharingSwitch.isOn = customization.enableFileSharing

        let switchRow = UIStackView(arrangedSubviews: [switchLabel, fileSharingSwitch])
        switchRow.axis = .horizontal
        switchRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [
            bundleIDField,
            appNameField,
            versionField,
            minOSField,
            switchRow
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            bundleIDField.heightAnchor.constraint(equalToConstant: 44),
            appNameField.heightAnchor.constraint(equalToConstant: 44),
            versionField.heightAnchor.constraint(equalToConstant: 44),
            minOSField.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func styleTextField(_ tf: UITextField) {
        tf.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.2, alpha: 1.0) : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        }
        tf.layer.cornerRadius = 10
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.systemGray4.cgColor
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        tf.leftView = padding
        tf.leftViewMode = .always
    }

    @objc private func saveTapped() {
        customization.bundleID = bundleIDField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        customization.appName = appNameField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        customization.version = versionField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        customization.minimumOS = minOSField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        customization.enableFileSharing = fileSharingSwitch.isOn

        onSave?(customization)
        navigationController?.popViewController(animated: true)
    }
}
