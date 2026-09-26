import UIKit

public struct SoulSignTheme {
    // Primary Brand Colors
    public static let primary = UIColor(red: 0.08, green: 0.44, blue: 0.98, alpha: 1.0) // iOS vibrant blue
    public static let primaryDark = UIColor(red: 0.04, green: 0.32, blue: 0.78, alpha: 1.0)
    public static let success = UIColor(red: 0.16, green: 0.78, blue: 0.42, alpha: 1.0) // Green
    public static let warning = UIColor(red: 1.00, green: 0.65, blue: 0.15, alpha: 1.0) // Orange / Yellow
    public static let danger = UIColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 1.0)  // Red
    
    // Backgrounds & Surfaces
    public static var background: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
                : UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        }
    }
    
    public static var cardBackground: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1.0)
                : UIColor.white
        }
    }
    
    public static var cardBorder: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.22, alpha: 1.0)
                : UIColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1.0)
        }
    }
    
    public static var secondaryText: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.60, alpha: 1.0)
                : UIColor(red: 0.45, green: 0.48, blue: 0.54, alpha: 1.0)
        }
    }

    // Card View Helper
    public static func styleCardView(_ view: UIView) {
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = cardBorder.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 6
        view.layer.shadowOpacity = 0.05
    }
    
    // Primary Button Helper
    public static func stylePrimaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = primary
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = primary.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.25
    }
}
