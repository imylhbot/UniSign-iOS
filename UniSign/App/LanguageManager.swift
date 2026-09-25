import Foundation

public enum AppLanguage: String {
    case chinese = "zh-Hans"
    case english = "en"
    
    public var displayName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
}

/// Global language manager providing Simplified Chinese as default with bilingual switching
public class LanguageManager {
    public static let shared = LanguageManager()
    public static let languageChangedNotification = Notification.Name("UniSign_LanguageChanged")
    
    private let key = "UniSign_CurrentLanguage"
    
    public var currentLanguage: AppLanguage {
        get {
            let saved = UserDefaults.standard.string(forKey: key) ?? AppLanguage.chinese.rawValue
            return AppLanguage(rawValue: saved) ?? .chinese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NotificationCenter.default.post(name: LanguageManager.languageChangedNotification, object: nil)
        }
    }
    
    public func localized(_ chinese: String, _ english: String) -> String {
        return currentLanguage == .chinese ? chinese : english
    }
}

public func L(_ zh: String, _ en: String) -> String {
    return LanguageManager.shared.localized(zh, en)
}
