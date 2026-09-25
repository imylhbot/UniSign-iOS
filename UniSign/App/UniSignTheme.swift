import UIKit

// MARK: - Design System & UI Components
public struct UniSignTheme {
    public static let primaryColor = UIColor(red: 0.05, green: 0.45, blue: 0.95, alpha: 1.0)
    public static let secondaryColor = UIColor(red: 0.35, green: 0.35, blue: 0.90, alpha: 1.0)
    public static let appleOrange = UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
    public static let cardBackground = UIColor.secondarySystemGroupedBackground
    public static let pageBackground = UIColor.systemGroupedBackground
    public static let cardCornerRadius: CGFloat = 16
    
    public static func applyGlobalAppearance() {
        // TabBar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
        
        // NavigationBar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        }
    }
}

// MARK: - Modern Card Container
public class CardView: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupCard()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard()
    }
    
    private func setupCard() {
        backgroundColor = UniSignTheme.cardBackground
        layer.cornerRadius = UniSignTheme.cardCornerRadius
        layer.masksToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
    }
}

// MARK: - Modern Gradient & Action Button
public class GradientButton: UIButton {
    private let gradientLayer = CAGradientLayer()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var originalTitle: String?
    
    public enum Style {
        case primaryCyber
        case appleBrand
        case destructive
        case secondaryGray
    }
    
    public var buttonStyle: Style = .primaryCyber {
        didSet { updateColors() }
    }
    
    public init(title: String, style: Style = .primaryCyber, icon: UIImage? = nil) {
        super.init(frame: .zero)
        self.buttonStyle = style
        self.originalTitle = title
        
        layer.cornerRadius = 14
        layer.masksToBounds = true
        titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        
        if let icon = icon {
            setImage(icon.withRenderingMode(.alwaysTemplate), for: .normal)
            tintColor = .white
            imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        }
        
        setTitle(title, for: .normal)
        setTitleColor(.white, for: .normal)
        
        gradientLayer.cornerRadius = 14
        layer.insertSublayer(gradientLayer, at: 0)
        
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        
        updateColors()
        
        addTarget(self, action: #selector(btnTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(btnTouchUp), for: [.touchUpInside, .touchCancel, .touchDragExit])
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        updateColors()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    private func updateColors() {
        switch buttonStyle {
        case .primaryCyber:
            gradientLayer.colors = [
                UIColor(red: 0.05, green: 0.48, blue: 0.98, alpha: 1.0).cgColor,
                UIColor(red: 0.35, green: 0.32, blue: 0.90, alpha: 1.0).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        case .appleBrand:
            gradientLayer.colors = [
                UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1.0).cgColor,
                UIColor(red: 0.95, green: 0.40, blue: 0.10, alpha: 1.0).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        case .destructive:
            gradientLayer.colors = [
                UIColor.systemRed.cgColor,
                UIColor(red: 0.8, green: 0.1, blue: 0.2, alpha: 1.0).cgColor
            ]
        case .secondaryGray:
            gradientLayer.colors = [
                UIColor.systemGray5.cgColor,
                UIColor.systemGray4.cgColor
            ]
            setTitleColor(.label, for: .normal)
            tintColor = .label
            activityIndicator.color = .label
        }
    }
    
    @objc private func btnTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.alpha = 0.9
        }
    }
    
    @objc private func btnTouchUp() {
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }
    
    public func setLoading(_ loading: Bool, title: String? = nil) {
        isEnabled = !loading
        if loading {
            if originalTitle == nil { originalTitle = self.title(for: .normal) }
            setTitle(title ?? originalTitle, for: .normal)
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
            if let orig = originalTitle {
                setTitle(orig, for: .normal)
            }
        }
    }
}

// MARK: - Status Pill Badge
public class PillBadge: UIView {
    private let label = UILabel()
    
    public enum Style {
        case success
        case warning
        case danger
        case info
    }
    
    public init(text: String, style: Style = .info) {
        super.init(frame: .zero)
        layer.cornerRadius = 10
        layer.masksToBounds = true
        
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
        
        update(text: text, style: style)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public func update(text: String, style: Style) {
        label.text = text
        switch style {
        case .success:
            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.18)
            label.textColor = .systemGreen
        case .warning:
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
            label.textColor = .systemOrange
        case .danger:
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.18)
            label.textColor = .systemRed
        case .info:
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.18)
            label.textColor = .systemBlue
        }
    }
}

// MARK: - Floating Progress HUD
public class ProgressHUD: UIView {
    public static let shared = ProgressHUD()
    
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let spinner = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    
    private override init(frame: CGRect) {
        super.init(frame: frame)
        setupHUD()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHUD()
    }
    
    private func setupHUD() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        translatesAutoresizingMaskIntoConstraints = false
        alpha = 0
        
        blurView.layer.cornerRadius = 20
        blurView.layer.masksToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(stack)
        
        spinner.startAnimating()
        stack.addArrangedSubview(spinner)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)
        
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0
        stack.addArrangedSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            blurView.centerXAnchor.constraint(equalTo: centerXAnchor),
            blurView.centerYAnchor.constraint(equalTo: centerYAnchor),
            blurView.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            blurView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            
            stack.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -20)
        ])
    }
    
    public func show(in view: UIView, title: String, detail: String? = nil) {
        removeFromSuperview()
        frame = view.bounds
        view.addSubview(self)
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = (detail == nil || detail!.isEmpty)
        
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }
    
    public func update(title: String, detail: String? = nil) {
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = (detail == nil || detail!.isEmpty)
    }
    
    public func hide() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
