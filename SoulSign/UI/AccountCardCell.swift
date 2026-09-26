import UIKit

class AccountCardCell: UITableViewCell {
    static let identifier = "AccountCardCell"

    private let containerView = UIView()
    private let emailLabel = UILabel()
    private let activeBadge = UILabel()
    private let teamLabel = UILabel()

    // 3-App Quota UI
    private let quotaTitleLabel = UILabel()
    private let quotaCountLabel = UILabel()
    private let quotaProgressView = UIProgressView(progressViewStyle: .default)

    // Session Status UI
    private let statusBadge = UILabel()
    private let lastCheckedLabel = UILabel()

    // Action Buttons
    private let checkButton = UIButton(type: .system)
    private let renewButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)

    var onCheckValidity: (() -> Void)?
    var onRenewApps: (() -> Void)?
    var onMoreActions: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        SoulSignTheme.styleCardView(containerView)
        contentView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Email & Active Badge
        emailLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        emailLabel.textColor = .label

        activeBadge.text = "活跃签名账号"
        activeBadge.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        activeBadge.textColor = .white
        activeBadge.backgroundColor = SoulSignTheme.primary
        activeBadge.layer.cornerRadius = 6
        activeBadge.clipsToBounds = true
        activeBadge.textAlignment = .center

        let headerRow = UIStackView(arrangedSubviews: [emailLabel, activeBadge, UIView()])
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center

        // Team info
        teamLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        teamLabel.textColor = SoulSignTheme.secondaryText

        // Quota Section
        quotaTitleLabel.text = "3-App 开发者签名配�?"
        quotaTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        quotaTitleLabel.textColor = .secondaryLabel

        quotaCountLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)

        let quotaRow = UIStackView(arrangedSubviews: [quotaTitleLabel, quotaCountLabel, UIView()])
        quotaRow.axis = .horizontal
        quotaRow.spacing = 6

        quotaProgressView.trackTintColor = UIColor.systemGray5
        quotaProgressView.layer.cornerRadius = 4
        quotaProgressView.clipsToBounds = true

        // Status Section
        statusBadge.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        statusBadge.layer.cornerRadius = 6
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center

        lastCheckedLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        lastCheckedLabel.textColor = .tertiaryLabel

        let statusRow = UIStackView(arrangedSubviews: [statusBadge, lastCheckedLabel, UIView()])
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center

        // Action Buttons Row
        styleActionButton(checkButton, title: "🔍 检测有效�?, color: SoulSignTheme.primary)
        checkButton.addTarget(self, action: #selector(checkTapped), for: .touchUpInside)

        styleActionButton(renewButton, title: "�?一键续�?, color: SoulSignTheme.success)
        renewButton.addTarget(self, action: #selector(renewTapped), for: .touchUpInside)

        styleActionButton(moreButton, title: "••�?更多", color: .systemGray)
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)

        let buttonRow = UIStackView(arrangedSubviews: [checkButton, renewButton, moreButton])
        buttonRow.axis = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 8

        let mainStack = UIStackView(arrangedSubviews: [
            headerRow,
            teamLabel,
            quotaRow,
            quotaProgressView,
            statusRow,
            buttonRow
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),

            activeBadge.heightAnchor.constraint(equalToConstant: 20),
            activeBadge.widthAnchor.constraint(equalToConstant: 80),
            quotaProgressView.heightAnchor.constraint(equalToConstant: 8),
            statusBadge.heightAnchor.constraint(equalToConstant: 22),
            statusBadge.widthAnchor.constraint(equalToConstant: 90),
            buttonRow.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func styleActionButton(_ button: UIButton, title: String, color: UIColor) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        button.setTitleColor(color, for: .normal)
        button.backgroundColor = color.withAlphaComponent(0.12)
        button.layer.cornerRadius = 8
    }

    func configure(with account: AppleAccount) {
        emailLabel.text = account.email
        activeBadge.isHidden = !account.isActive

        let team = account.teamName ?? account.teamID ?? "个人开发者团�?
        teamLabel.text = "团队: \(team)"

        // Configure 3-App Quota
        let used = AccountManager.shared.activeAppsCount(for: account.email)
        let total = AccountManager.maxQuotaPerAccount
        let remaining = AccountManager.shared.remainingQuota(for: account.email)

        quotaCountLabel.text = "\(used)/\(total) (可用: \(remaining) �?"
        quotaProgressView.progress = Float(used) / Float(total)

        if used >= total {
            quotaCountLabel.textColor = SoulSignTheme.danger
            quotaProgressView.progressTintColor = SoulSignTheme.danger
        } else if used == 2 {
            quotaCountLabel.textColor = SoulSignTheme.warning
            quotaProgressView.progressTintColor = SoulSignTheme.warning
        } else {
            quotaCountLabel.textColor = SoulSignTheme.success
            quotaProgressView.progressTintColor = SoulSignTheme.success
        }

        // Configure Session Status Badge
        statusBadge.text = account.sessionStatus.title
        switch account.sessionStatus {
        case .valid:
            statusBadge.backgroundColor = SoulSignTheme.success.withAlphaComponent(0.15)
            statusBadge.textColor = SoulSignTheme.success
        case .expired:
            statusBadge.backgroundColor = SoulSignTheme.danger.withAlphaComponent(0.15)
            statusBadge.textColor = SoulSignTheme.danger
        case .twoFactorRequired:
            statusBadge.backgroundColor = SoulSignTheme.warning.withAlphaComponent(0.15)
            statusBadge.textColor = SoulSignTheme.warning
        case .unchecked:
            statusBadge.backgroundColor = UIColor.systemGray5
            statusBadge.textColor = .secondaryLabel
        }

        if let lastChecked = account.lastCheckedDate {
            let df = DateFormatter()
            df.dateFormat = "MM-dd HH:mm"
            lastCheckedLabel.text = "检测于: \(df.string(from: lastChecked))"
        } else {
            lastCheckedLabel.text = "尚未检�?
        }
    }

    @objc private func checkTapped() {
        onCheckValidity?()
    }

    @objc private func renewTapped() {
        onRenewApps?()
    }

    @objc private func moreTapped() {
        onMoreActions?()
    }
}
