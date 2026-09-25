import UIKit

/// Modern Apple ID Login Sheet Controller
/// Provides real-time in-sheet loading state, smooth 2FA transition,
/// and inline error feedback without abrupt dismissals.
public class AppleIDLoginViewController: UIViewController {
    
    public var onLoginSuccess: (() -> Void)?
    
    // UI Elements
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let formCard = CardView()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let togglePasswordButton = UIButton(type: .custom)
    
    // 2FA Container
    private let twoFactorCard = CardView()
    private let twoFactorNoticeLabel = UILabel()
    private let twoFactorField = UITextField()
    
    // Status & Error
    private let errorLabel = UILabel()
    private let loginButton = GradientButton(
        title: L("安全登录并授权", "Sign In & Authorize"),
        style: .appleBrand,
        icon: UIImage(systemName: "applelogo")
    )
    private let cancelButton = UIButton(type: .system)
    
    private var isTwoFactorMode = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UniSignTheme.pageBackground
        setupUI()
        setupSheetPresentation()
    }
    
    private func setupSheetPresentation() {
        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24
            }
        }
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -30),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        // 1. Header (Apple logo & title)
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .center
        
        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = UIColor.label.withAlphaComponent(0.08)
        iconCircle.layer.cornerRadius = 32
        iconCircle.layer.masksToBounds = true
        iconCircle.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconCircle.heightAnchor.constraint(equalToConstant: 64).isActive = true
        
        iconImageView.image = UIImage(systemName: "applelogo")?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = .label
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32)
        ])
        headerStack.addArrangedSubview(iconCircle)
        
        titleLabel.text = L("登录 Apple ID", "Sign in with Apple ID")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        headerStack.addArrangedSubview(titleLabel)
        
        subtitleLabel.text = L(
            "用于获取个人 7 天免费开发者证书重签 IPA。\n每账号最多限制签名 3 个应用，凭据仅本地加密存储。",
            "Used to request 7-day free developer certs.\nMax 3 active apps per Apple ID. Stored encrypted on-device only."
        )
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        headerStack.addArrangedSubview(subtitleLabel)
        
        stackView.addArrangedSubview(headerStack)
        
        // 2. Form Inputs Card
        let formInnerStack = UIStackView()
        formInnerStack.axis = .vertical
        formInnerStack.spacing = 0
        formInnerStack.translatesAutoresizingMaskIntoConstraints = false
        formCard.addSubview(formInnerStack)
        
        NSLayoutConstraint.activate([
            formInnerStack.topAnchor.constraint(equalTo: formCard.topAnchor),
            formInnerStack.bottomAnchor.constraint(equalTo: formCard.bottomAnchor),
            formInnerStack.leadingAnchor.constraint(equalTo: formCard.leadingAnchor),
            formInnerStack.trailingAnchor.constraint(equalTo: formCard.trailingAnchor)
        ])
        
        // Email row
        let emailRow = createInputRow(
            textField: emailField,
            placeholder: L("Apple ID (邮箱)", "Apple ID (Email)"),
            iconName: "envelope.fill",
            isSecure: false
        )
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        formInnerStack.addArrangedSubview(emailRow)
        
        let divider = UIView()
        divider.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        formInnerStack.addArrangedSubview(divider)
        
        // Password row
        let passRow = createInputRow(
            textField: passwordField,
            placeholder: L("密码", "Password"),
            iconName: "lock.fill",
            isSecure: true
        )
        passwordField.isSecureTextEntry = true
        formInnerStack.addArrangedSubview(passRow)
        
        // Password eye button
        togglePasswordButton.setImage(UIImage(systemName: "eye.slash.fill"), for: .normal)
        togglePasswordButton.tintColor = .secondaryLabel
        togglePasswordButton.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        togglePasswordButton.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        passwordField.rightView = togglePasswordButton
        passwordField.rightViewMode = .always
        
        stackView.addArrangedSubview(formCard)
        
        // 3. Two-Factor Authentication Card (Initially Hidden)
        setupTwoFactorCard()
        stackView.addArrangedSubview(twoFactorCard)
        twoFactorCard.isHidden = true
        
        // 4. Inline Error Label
        errorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true
        stackView.addArrangedSubview(errorLabel)
        
        // 5. Action Buttons
        loginButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        loginButton.addTarget(self, action: #selector(performLogin), for: .touchUpInside)
        stackView.addArrangedSubview(loginButton)
        
        cancelButton.setTitle(L("取消", "Cancel"), for: .normal)
        cancelButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        stackView.addArrangedSubview(cancelButton)
    }
    
    private func setupTwoFactorCard() {
        let tfStack = UIStackView()
        tfStack.axis = .vertical
        tfStack.spacing = 8
        tfStack.translatesAutoresizingMaskIntoConstraints = false
        twoFactorCard.addSubview(tfStack)
        
        NSLayoutConstraint.activate([
            tfStack.topAnchor.constraint(equalTo: twoFactorCard.topAnchor, constant: 14),
            tfStack.bottomAnchor.constraint(equalTo: twoFactorCard.bottomAnchor, constant: -14),
            tfStack.leadingAnchor.constraint(equalTo: twoFactorCard.leadingAnchor, constant: 14),
            tfStack.trailingAnchor.constraint(equalTo: twoFactorCard.trailingAnchor, constant: -14)
        ])
        
        twoFactorNoticeLabel.text = L(
            "⚠️ 账号已开启双重认证，请在已受信任的 Apple 设备上允许登录，并在下方输入 6 位验证码：",
            "⚠️ Two-Factor Auth required. Allow sign-in on your trusted Apple device and enter the 6-digit code:"
        )
        twoFactorNoticeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        twoFactorNoticeLabel.textColor = .systemOrange
        twoFactorNoticeLabel.numberOfLines = 0
        tfStack.addArrangedSubview(twoFactorNoticeLabel)
        
        twoFactorField.placeholder = L("输入 6 位验证码", "Enter 6-digit Code")
        twoFactorField.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        twoFactorField.textAlignment = .center
        twoFactorField.keyboardType = .numberPad
        twoFactorField.borderStyle = .roundedRect
        twoFactorField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        tfStack.addArrangedSubview(twoFactorField)
    }
    
    private func createInputRow(textField: UITextField, placeholder: String, iconName: String, isSecure: Bool) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 52).isActive = true
        
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)
        
        textField.placeholder = placeholder
        textField.font = .systemFont(ofSize: 15)
        textField.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(textField)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return row
    }
    
    @objc private func togglePasswordVisibility() {
        passwordField.isSecureTextEntry.toggle()
        let icon = passwordField.isSecureTextEntry ? "eye.slash.fill" : "eye.fill"
        togglePasswordButton.setImage(UIImage(systemName: icon), for: .normal)
    }
    
    @objc private func cancelAction() {
        dismiss(animated: true)
    }
    
    @objc private func performLogin() {
        guard let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            showError(L("请输入有效的 Apple ID 邮箱账号", "Please enter a valid Apple ID email"))
            return
        }
        guard let password = passwordField.text, !password.isEmpty else {
            showError(L("请输入 Apple ID 密码", "Please enter your password"))
            return
        }
        
        let code = twoFactorField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Set loading state without closing modal!
        hideError()
        setInputsEnabled(false)
        loginButton.setLoading(true, title: L("正在安全连接 Apple 服务器...", "Connecting to Apple Servers..."))
        
        AppleDeveloperService.shared.authenticate(appleID: email, password: password, twoFactorCode: code) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setInputsEnabled(true)
                
                switch result {
                case .success(let session):
                    // Login success!
                    self.loginButton.setLoading(false)
                    self.loginButton.setTitle("✓ " + L("登录成功！", "Login Successful!"), for: .normal)
                    self.loginButton.buttonStyle = .primaryCyber
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    
                    let account = AppleAccount(
                        email: email,
                        password: password,
                        teamID: session.teamID,
                        teamName: session.teamName,
                        isActive: true
                    )
                    AppleAccountManager.shared.addOrUpdateAccount(account)
                    self.onLoginSuccess?()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.dismiss(animated: true)
                    }
                    
                case .failure(let err):
                    self.loginButton.setLoading(false)
                    switch err {
                    case .twoFactorRequired:
                        self.revealTwoFactorInput()
                    case .invalidCredentials:
                        self.showError(L("账号或密码不正确，请重新输入。", "Invalid Apple ID or password."))
                    case .networkError(let netErr):
                        self.showError(L("网络连接异常：\(netErr.localizedDescription)。请检查设备网络或重试。", "Network error: \(netErr.localizedDescription)"))
                    default:
                        self.showError(err.localizedDescription)
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    self.shakeView(self.formCard)
                }
            }
        }
    }
    
    private func revealTwoFactorInput() {
        guard twoFactorCard.isHidden else {
            showError(L("两步验证码错误，请重新在设备上查看并输入", "2FA code invalid, please check trusted device"))
            return
        }
        UIView.animate(withDuration: 0.3) {
            self.twoFactorCard.isHidden = false
            self.loginButton.setTitle(L("提交验证码并登录", "Submit 2FA & Sign In"), for: .normal)
            self.twoFactorField.becomeFirstResponder()
        }
    }
    
    private func setInputsEnabled(_ enabled: Bool) {
        emailField.isEnabled = enabled
        passwordField.isEnabled = enabled
        twoFactorField.isEnabled = enabled
        cancelButton.isEnabled = enabled
    }
    
    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
    }
    
    private func hideError() {
        errorLabel.isHidden = true
    }
    
    private func shakeView(_ v: UIView) {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration = 0.5
        anim.values = [-12, 12, -8, 8, -4, 4, 0]
        v.layer.add(anim, forKey: "shake")
    }
}
