import UIKit

public class MainTabBarController: UITabBarController {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let signVC = UINavigationController(rootViewController: SignWorkflowViewController())
        signVC.tabBarItem = UITabBarItem(title: "Sign & Modify", image: UIImage(systemName: "signature"), tag: 0)
        
        let certVC = UINavigationController(rootViewController: CertificateManagerViewController())
        certVC.tabBarItem = UITabBarItem(title: "Certificates", image: UIImage(systemName: "person.badge.key"), tag: 1)
        
        let settingsVC = UINavigationController(rootViewController: SettingsViewController())
        settingsVC.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 2)
        
        tabBar.tintColor = .systemBlue
        viewControllers = [signVC, certVC, settingsVC]
    }
}
