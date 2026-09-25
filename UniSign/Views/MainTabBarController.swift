import UIKit

public class MainTabBarController: UITabBarController {
    
    private var libraryNav: UINavigationController!
    private var signNav: UINavigationController!
    private var certNav: UINavigationController!
    private var settingsNav: UINavigationController!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        UniSignTheme.applyGlobalAppearance()
        
        let libraryVC = AppLibraryViewController()
        libraryNav = UINavigationController(rootViewController: libraryVC)
        libraryNav.navigationBar.prefersLargeTitles = true
        
        let signVC = SignWorkflowViewController()
        signNav = UINavigationController(rootViewController: signVC)
        signNav.navigationBar.prefersLargeTitles = true
        
        let certVC = CertificateManagerViewController()
        certNav = UINavigationController(rootViewController: certVC)
        certNav.navigationBar.prefersLargeTitles = true
        
        let settingsVC = SettingsViewController()
        settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.navigationBar.prefersLargeTitles = true
        
        tabBar.tintColor = UniSignTheme.primaryColor
        viewControllers = [libraryNav, signNav, certNav, settingsNav]
        
        updateTabTitles()
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    @objc private func languageDidChange() {
        updateTabTitles()
    }
    
    private func updateTabTitles() {
        libraryNav.tabBarItem = UITabBarItem(
            title: L("应用资源库", "Library"),
            image: UIImage(systemName: "square.grid.2x2"),
            selectedImage: UIImage(systemName: "square.grid.2x2.fill")
        )
        
        signNav.tabBarItem = UITabBarItem(
            title: L("签名与定制", "Sign & Modify"),
            image: UIImage(systemName: "signature"),
            selectedImage: UIImage(systemName: "signature")
        )
        
        certNav.tabBarItem = UITabBarItem(
            title: L("证书中心", "Certificates"),
            image: UIImage(systemName: "person.crop.circle.badge.checkmark"),
            selectedImage: UIImage(systemName: "person.crop.circle.badge.checkmark.fill")
        )
        
        settingsNav.tabBarItem = UITabBarItem(
            title: L("系统设置", "Settings"),
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
