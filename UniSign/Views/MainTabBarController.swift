import UIKit

public class MainTabBarController: UITabBarController {
    
    private var libraryNav: UINavigationController!
    private var signNav: UINavigationController!
    private var certNav: UINavigationController!
    private var settingsNav: UINavigationController!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let libraryVC = AppLibraryViewController()
        libraryNav = UINavigationController(rootViewController: libraryVC)
        
        let signVC = SignWorkflowViewController()
        signNav = UINavigationController(rootViewController: signVC)
        
        let certVC = CertificateManagerViewController()
        certNav = UINavigationController(rootViewController: certVC)
        
        let settingsVC = SettingsViewController()
        settingsNav = UINavigationController(rootViewController: settingsVC)
        
        tabBar.tintColor = .systemBlue
        viewControllers = [libraryNav, signNav, certNav, settingsNav]
        
        updateTabTitles()
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: LanguageManager.languageChangedNotification, object: nil)
    }
    
    @objc private func languageDidChange() {
        updateTabTitles()
    }
    
    private func updateTabTitles() {
        libraryNav.tabBarItem = UITabBarItem(title: L("应用资源库", "Library"), image: UIImage(systemName: "folder.fill"), tag: 0)
        signNav.tabBarItem = UITabBarItem(title: L("签名与定制", "Sign & Modify"), image: UIImage(systemName: "signature"), tag: 1)
        certNav.tabBarItem = UITabBarItem(title: L("证书与UDID", "Certs & UDID"), image: UIImage(systemName: "person.badge.key"), tag: 2)
        settingsNav.tabBarItem = UITabBarItem(title: L("系统设置", "Settings"), image: UIImage(systemName: "gearshape"), tag: 3)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
