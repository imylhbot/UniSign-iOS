import UIKit

class AddAccountViewController: UIViewController {
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let webLoginButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "添加 Apple ID"
        view.backgroundColor = SoulSignTheme.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        setupUI()
    }

    private func setupUI() {
        let card = UIView()
        SoulSignTheme.styleCardView(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        let titleLabel = UILabel()
        titleLabel.text = "Apple 开发者账号登录"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label

        let noteLabel = UILabel()
        noteLabel.text = "参考 SideStore 登录协议，密码仅保存在本地 iOS 钥匙串 (Keychain) 中，用于生成签名描述文件，每个账号限签 3 个 App。"
        noteLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        noteLabel.textColor = SoulSignTheme.secondaryText
        noteLabel.numberOfLines = 0

        styleInputField(emailField, placeholder: "Apple ID 邮箱账号", isSecure: false)
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none

        styleInputField(passwordField, placeholder: "Apple ID 密码", isSecure: true)

        SoulSignTheme.stylePrimaryButton(loginButton, title: "安全登录并绑定")
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        webLoginButton.setTitle("🌐 使用 Apple 网页快捷登录", for: .normal)
        webLoginButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        webLoginButton.setTitleColor(SoulSignTheme.primary, for: .normal)
        webLoginButton.backgroundColor = SoulSignTheme.primary.withAlphaComponent(0.1)
        webLoginButton.layer.cornerRadius = 12
        webLoginButton.addTarget(self, action: #selector(webLoginTapped), for: .touchUpInside)

        activityIndicator.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            noteLabel,
            emailField,
            passwordField,
            loginButton,
            activityIndicator,
            webLoginButton
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            emailField.heightAnchor.constraint(equalToConstant: 44),
            passwordField.heightAnchor.constraint(equalToConstant: 44),
            loginButton.heightAnchor.constraint(equalToConstant: 48),
            webLoginButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func styleInputField(_ tf: UITextField, placeholder: String, isSecure: Bool) {
        tf.placeholder = placeholder
        tf.isSecureTextEntry = isSecure
        tf.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.2, alpha: 1.0) : UIColor(white: 0.96, alpha: 1.0)
        }
        tf.layer.cornerRadius = 10
        tf.layer.borderWidth = 1
        tf.layer.borderColor = SoulSignTheme.cardBorder.cgColor

        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        tf.leftView = padding
        tf.leftViewMode = .always
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func webLoginTapped() {
        let webVC = WebAuthViewController()
        let nav = UINavigationController(rootViewController: webVC)
        present(nav, animated: true)
    }

    @objc private func loginTapped() {
        guard let email = emailField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !email.isEmpty else {
            showAlert(title: "提示", message: "请输入 Apple ID 邮箱")
            return
        }

        guard let password = passwordField.text, !password.isEmpty else {
            showAlert(title: "提示", message: "请输入密码")
            return
        }

        setLoading(true)

        GrandSlamClient.shared.authenticate(appleID: email, password: password) { [weak self] (result: Result<DeveloperSession, AuthError>) in
            guard let self = self else { return }

            switch result {
            case .success(let session):
                DeveloperPortalAPI.shared.listTeams(session: session) { teamResult in
                    self.setLoading(false)
                    var teamID: String? = nil
                    var teamName: String? = nil
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
                    self.dismiss(animated: true)
                }

            case .failure(let error):
                self.setLoading(false)
                if case AuthError.twoFactorRequired = error {
                    self.prompt2FACode(email: email, password: password)
                } else {
                    self.showAlert(title: "登录失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func prompt2FACode(email: String, password: String) {
        let alert = UIAlertController(title: "双重认证 (2FA)", message: "请输入已发送至受信任设备的 6 位验证码", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "6 位数字验证码"
            tf.keyboardType = .numberPad
        }

        alert.addAction(UIAlertAction(title: "验证", style: .default) { [weak self] _ in
            guard let self = self,
                  let code = alert.textFields?.first?.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                  !code.isEmpty else {
                return
            }

            self.setLoading(true)
            GrandSlamClient.shared.submitTwoFactorCode(code: code) { (result: Result<DeveloperSession, AuthError>) in
                switch result {
                case .success(let session):
                    DeveloperPortalAPI.shared.listTeams(session: session) { teamResult in
                        self.setLoading(false)
                        var teamID: String? = nil
                        var teamName: String? = nil
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
                        self.dismiss(animated: true)
                    }
                case .failure(let err):
                    self.setLoading(false)
                    self.showAlert(title: "2FA 验证失败", message: err.localizedDescription)
                }
            }
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
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
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
