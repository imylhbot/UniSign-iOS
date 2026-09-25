import UIKit

public class MainTabBarController: UITabBarController {
    
    private var signNav: UINavigationController!
    private var libraryNav: UINavigationController!
    private var certNav: UINavigationController!
    private var configNav: UINavigationController!
    private var settingsNav: UINavigationController!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        UniSignTheme.applyGlobalAppearance()
        
        // 1. Projects / Sign Workflow
        let signVC = SignWorkflowViewController()
        signNav = UINavigationController(rootViewController: signVC)
        signNav.navigationBar.prefersLargeTitles = true
        
        // 2. Applications Library
        let libraryVC = AppLibraryViewController()
        libraryNav = UINavigationController(rootViewController: libraryVC)
        libraryNav.navigationBar.prefersLargeTitles = true
        
        // 3. Certificate Manager
        let certVC = CertificateManagerViewController()
        certNav = UINavigationController(rootViewController: certVC)
        certNav.navigationBar.prefersLargeTitles = true
        
        // 4. Application & Signing Config
        let configVC = SigningConfigViewController()
        configNav = UINavigationController(rootViewController: configVC)
        configNav.navigationBar.prefersLargeTitles = true
        
        // 5. Software Settings
        let settingsVC = SettingsViewController()
        settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.navigationBar.prefersLargeTitles = true
        
        tabBar.tintColor = UniSignTheme.primaryColor
        viewControllers = [signNav, libraryNav, certNav, configNav, settingsNav]
        
        updateTabTitles()
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    @objc private func languageDidChange() {
        updateTabTitles()
    }
    
    private func updateTabTitles() {
        signNav.tabBarItem = UITabBarItem(
            title: L("项目", "Projects"),
            image: UIImage(systemName: "shippingbox"),
            selectedImage: UIImage(systemName: "shippingbox.fill")
        )
        
        libraryNav.tabBarItem = UITabBarItem(
            title: L("应用", "Apps"),
            image: UIImage(systemName: "square.stack.3d.up"),
            selectedImage: UIImage(systemName: "square.stack.3d.up.fill")
        )
        
        certNav.tabBarItem = UITabBarItem(
            title: L("证书", "Certs"),
            image: UIImage(systemName: "person.crop.circle.badge.checkmark"),
            selectedImage: UIImage(systemName: "person.crop.circle.badge.checkmark.fill")
        )
        
        configNav.tabBarItem = UITabBarItem(
            title: L("配置", "Config"),
            image: UIImage(systemName: "slider.horizontal.3"),
            selectedImage: UIImage(systemName: "slider.horizontal.3")
        )
        
        settingsNav.tabBarItem = UITabBarItem(
            title: L("设置", "Settings"),
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
