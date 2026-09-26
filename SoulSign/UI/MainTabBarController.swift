import UIKit

class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }

    private func setupTabs() {
        let accountsVC = UINavigationController(rootViewController: AccountsViewController())
        accountsVC.tabBarItem = UITabBarItem(
            title: "璐﹀彿涓蹇",
            image: UIImage(systemName: "person.2.circle"),
            selectedImage: UIImage(systemName: "person.2.circle.fill")
        )

        let signVC = UINavigationController(rootViewController: SignViewController())
        signVC.tabBarItem = UITabBarItem(
            title: "绛惧悕",
            image: UIImage(systemName: "signature"),
            selectedImage: UIImage(systemName: "signature")
        )

        let libraryVC = UINavigationController(rootViewController: AppLibraryViewController())
        libraryVC.tabBarItem = UITabBarItem(
            title: "搴旂敤搴?,
            image: UIImage(systemName: "square.stack.3d.up"),
            selectedImage: UIImage(systemName: "square.stack.3d.up.fill")
        )

        let settingsVC = UINavigationController(rootViewController: SettingsViewController())
        settingsVC.tabBarItem = UITabBarItem(
            title: "璁剧疆",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        viewControllers = [accountsVC, signVC, libraryVC, settingsVC]
        selectedIndex = 1 // Default to Sign workbench
    }

    private func setupAppearance() {
        tabBar.tintColor = SoulSignTheme.primary

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}
