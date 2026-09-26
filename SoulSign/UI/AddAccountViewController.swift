import UIKit

class AddAccountViewController: UIViewController {
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let webLoginButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "娣诲姞 Apple ID"
        view.backgroundColor = SoulSignTheme.background
        setupUI()
    }

    private func setupUI() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "鍙栨秷",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        let container = UIView()
        SoulSignTheme.styleCardView(container)
        view.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        styleTextField(emailField, placeholder: "Apple ID 璐﹀彿 (閭绠)")
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none

        styleTextField(passwordField, placeholder: "Apple ID 瀵嗙爜")
        passwordField.isSecureTextEntry = true

        SoulSignTheme.stylePrimaryButton(loginButton, title: "鐧诲綍骞舵巿鏉?)
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        webLoginButton.setTitle("馃寪 閬囧埌椋庢帶锛熶娇鐢ㄧ綉椤电増 WebAuth 鐧诲綍", for: .normal)
        webLoginButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        webLoginButton.setTitleColor(SoulSignTheme.primary, for: .normal)
        webLoginButton.addTarget(self, action: #selector(webLoginTapped), for: .touchUpInside)

        activityIndicator.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            emailField,
            passwordField,
            loginButton,
            activityIndicator,
            webLoginButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            emailField.heightAnchor.constraint(equalToConstant: 44),
            passwordField.heightAnchor.constraint(equalToConstant: 44),
            loginButton.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func styleTextField(_ tf: UITextField, placeholder: String) {
        tf.placeholder = placeholder
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

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func loginTapped() {
        guard let email = emailField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !email.isEmpty else {
            showAlert(title: "鎻愮ず", message: "璇疯緭鍏ユ湁鏁堢殑 Apple ID 璐﹀彿銆?)
            return
        }

        guard let pwd = passwordField.text, !pwd.isEmpty else {
            showAlert(title: "鎻愮ず", message: "璇疯緭鍏?Apple ID 瀵嗙爜銆?)
            return
        }

        performLogin(email: email, password: pwd, twoFactorCode: nil)
    }

    private func performLogin(email: String, password: String, twoFactorCode: String?) {
        setLoading(true)

        GrandSlamClient.shared.authenticate(
            appleID: email,
            password: password,
            twoFactorCode: twoFactorCode
        ) { [weak self] result in
            self?.setLoading(false)

            switch result {
            case .success(let session):
                // Account logged in successfully, fetch developer team
                DeveloperPortalAPI.shared.listTeams(session: session) { teamResult in
                    var teamID: String?
                    var teamName: String?
                    if case .success(let teams) = teamResult, let first = teams.first {
                        teamID = first.teamID
                        teamName = first.name
                    }
                    AccountManager.shared.addOrUpdateAccount(
                        email: email,
                        password: password,
                        session: session,
                        teamID: teamID,
                        teamName: teamName
                    )
                    self?.dismiss(animated: true)
                }

            case .failure(let error):
                if case .twoFactorRequired = error {
                    self?.promptFor2FACode(email: email, password: password)
                } else {
                    self?.showAlert(title: "鐧诲綍澶辫触", message: error.localizedDescription)
                }
            }
        }
    }

    private func promptFor2FACode(email: String, password: String) {
        let alert = UIAlertController(
            title: "鍙岄噸璁よ瘉 (2FA)",
            message: "宸插悜鎮ㄧ殑鍙椾俊浠?Apple 璁惧囧彂閫佷簡 6 浣嶉獙璇佺爜锛岃疯緭鍏ヤ互缁х画锛",
            preferredStyle: .alert
        )

        alert.addTextField { tf in
            tf.placeholder = "6 浣嶆暟瀛楅獙璇佺爜"
            tf.keyboardType = .numberPad
            tf.textAlignment = .center
        }

        alert.addAction(UIAlertAction(title: "纭璁", style: .default, handler: { [weak self] _ in
            let code = alert.textFields?.first?.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            self?.performLogin(email: email, password: password, twoFactorCode: code)
        }))

        alert.addAction(UIAlertAction(title: "鍙栨秷", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func webLoginTapped() {
        let webVC = WebAuthViewController()
        let nav = UINavigationController(rootViewController: webVC)
        present(nav, animated: true)
    }

    private func setLoading(_ loading: Bool) {
        if loading {
            activityIndicator.startAnimating()
            loginButton.isEnabled = false
            loginButton.alpha = 0.6
        } else {
            activityIndicator.stopAnimating()
            loginButton.isEnabled = true
            loginButton.alpha = 1.0
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "纭瀹", style: .default))
        present(alert, animated: true)
    }
}
