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
        titleLabel.text = "Apple 开发者账号绑定"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label

        let noteLabel = UILabel()
        noteLabel.text = "推荐优先使用 Apple 官方网页快捷登录，成功率极高且无苹果 GSA 拦截限制；每个账号限签 3 个 App。"
        noteLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        noteLabel.textColor = SoulSignTheme.secondaryText
        noteLabel.numberOfLines = 0

        // Web Login Button - Primary Recommendation
        SoulSignTheme.stylePrimaryButton(webLoginButton, title: "🌐 Apple 官方网页快捷登录 (推荐)")
        webLoginButton.addTarget(self, action: #selector(webLoginTapped), for: .touchUpInside)

        let dividerView = UIView()
        dividerView.backgroundColor = SoulSignTheme.cardBorder
        dividerView.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let orLabel = UILabel()
        orLabel.text = "或者直接输入账号密码登录 (SideStore 协议):"
        orLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        orLabel.textColor = .secondaryLabel

        styleInputField(emailField, placeholder: "Apple ID 邮箱账号", isSecure: false)
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none

        styleInputField(passwordField, placeholder: "Apple ID 密码", isSecure: true)

        loginButton.setTitle("安全登录并绑定", for: .normal)
        loginButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        loginButton.setTitleColor(SoulSignTheme.primary, for: .normal)
        loginButton.backgroundColor = SoulSignTheme.primary.withAlphaComponent(0.12)
        loginButton.layer.cornerRadius = 12
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        activityIndicator.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            noteLabel,
            webLoginButton,
            dividerView,
            orLabel,
            emailField,
            passwordField,
            loginButton,
            activityIndicator
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            webLoginButton.heightAnchor.constraint(equalToConstant: 48),
            emailField.heightAnchor.constraint(equalToConstant: 44),
            passwordField.heightAnchor.constraint(equalToConstant: 44),
            loginButton.heightAnchor.constraint(equalToConstant: 46)
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
        webVC.initialEmail = emailField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
                    AppLogger.shared.log("Apple ID 添加成功: \(email)", category: .auth)
                    self.dismiss(animated: true)
                }

            case .failure(let error):
                self.setLoading(false)
                if case AuthError.twoFactorRequired = error {
                    self.prompt2FACode(email: email, password: password)
                } else {
                    let alert = UIAlertController(title: "登录提示", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "使用网页快捷登录 (推荐)", style: .default) { [weak self] _ in
                        self?.webLoginTapped()
                    })
                    alert.addAction(UIAlertAction(title: "重试", style: .cancel))
                    self.present(alert, animated: true)
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
                        AppLogger.shared.log("2FA 验证通过，绑定成功: \(email)", category: .auth)
                        self.dismiss(animated: true)
                    }
                case .failure(let err):
                    self.setLoading(false)
                    let errAlert = UIAlertController(title: "2FA 验证失败", message: err.localizedDescription, preferredStyle: .alert)
                    errAlert.addAction(UIAlertAction(title: "使用网页快捷登录", style: .default) { [weak self] _ in
                        self?.webLoginTapped()
                    })
                    errAlert.addAction(UIAlertAction(title: "重试", style: .cancel))
                    self.present(errAlert, animated: true)
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
            webLoginButton.isEnabled = false
        } else {
            activityIndicator.stopAnimating()
            loginButton.isEnabled = true
            loginButton.alpha = 1.0
            webLoginButton.isEnabled = true
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
