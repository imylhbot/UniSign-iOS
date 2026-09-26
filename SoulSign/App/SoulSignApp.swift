import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        let mainTabBar = MainTabBarController()
        window.rootViewController = mainTabBar
        self.window = window
        window.makeKeyAndVisible()

        // Handle URL or incoming IPA file
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "soulsign" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                // Check if UDID is returned from OTA profile
                if let udidItem = components.queryItems?.first(where: { $0.name.lowercased() == "udid" }),
                   let udidValue = udidItem.value, !udidValue.isEmpty {
                    DeviceUDIDHelper.setCustomUDID(udidValue)
                    NotificationCenter.default.post(name: NSNotification.Name("SoulSignUDIDUpdatedNotification"), object: nil)
                    print("[SoulSign] 成功�?URL Scheme 接收并同步设备真�?UDID: \(udidValue)")
                    return
                }
            }
            return
        }

        // Handle imported IPA or P12 via AirDrop or Files app
        let tempDest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempDest)
        try? FileManager.default.copyItem(at: url, to: tempDest)
        print("[SoulSign] 接收到外部导入文�? \(tempDest.path)")
        NotificationCenter.default.post(name: NSNotification.Name("SoulSignFileImportedNotification"), object: tempDest)
    }
}
