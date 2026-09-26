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
        title = "应用个性化定制"
        view.backgroundColor = SoulSignTheme.background
        setupNavigation()
        setupUI()
    }

    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存",
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

        bundleIDField.placeholder = "Bundle Identifier (例如: com.app.signed)"
        bundleIDField.text = customization.bundleID
        styleTextField(bundleIDField)

        appNameField.placeholder = "应用显示名称"
        appNameField.text = customization.appName
        styleTextField(appNameField)

        versionField.placeholder = "版本号 (例如: 1.0.0)"
        versionField.text = customization.version
        styleTextField(versionField)

        minOSField.placeholder = "最低支持 iOS 版本 (例如: 15.0)"
        minOSField.text = customization.minimumOS
        styleTextField(minOSField)

        let switchLabel = UILabel()
        switchLabel.text = "开启系统「文件」应用沙盒互通"
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
