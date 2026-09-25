import UIKit

public class MainTabBarController: UITabBarController {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let libraryVC = UINavigationController(rootViewController: AppLibraryViewController())
        libraryVC.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "folder.fill"), tag: 0)
        
        let signVC = UINavigationController(rootViewController: SignWorkflowViewController())
        signVC.tabBarItem = UITabBarItem(title: "Sign & Modify", image: UIImage(systemName: "signature"), tag: 1)
        
        let certVC = UINavigationController(rootViewController: CertificateManagerViewController())
        certVC.tabBarItem = UITabBarItem(title: "Certs & UDID", image: UIImage(systemName: "person.badge.key"), tag: 2)
        
        let settingsVC = UINavigationController(rootViewController: SettingsViewController())
        settingsVC.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 3)
        
        tabBar.tintColor = .systemBlue
        viewControllers = [libraryVC, signVC, certVC, settingsVC]
    }
}
