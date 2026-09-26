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

        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleIncomingURL(url)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        checkClipboardForUDID()
    }

    private func checkClipboardForUDID() {
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !text.isEmpty else {
            return
        }

        if let parsed = DeviceUDIDHelper.parseUDIDResultURL(text) {
            let currentUDID = DeviceUDIDHelper.getDeviceUDID()
            if currentUDID != parsed.udid {
                let alert = UIAlertController(
                    title: "🔍 检测到设备 UDID 结果",
                    message: "剪贴板中检测到通过网页获取的设备参数：\n型号: \(parsed.product ?? "iOS 设备")\nUDID: \(parsed.udid)\n\n是否立即绑定至 SoulSign 签名环境？",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "立即绑定", style: .default, handler: { _ in
                    DeviceUDIDHelper.setDeviceInfo(udid: parsed.udid, product: parsed.product)
                    AppLogger.shared.log("已自动从剪贴板绑定 UDID: \(parsed.udid) (\(parsed.product ?? ""))", category: .server)
                }))
                alert.addAction(UIAlertAction(title: "忽略", style: .cancel))
                window?.rootViewController?.present(alert, animated: true)
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "soulsign" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if let udidItem = components.queryItems?.first(where: { $0.name.lowercased() == "udid" }),
                   let udidValue = udidItem.value, !udidValue.isEmpty {
                    let product = components.queryItems?.first(where: { $0.name.lowercased() == "product" })?.value
                    DeviceUDIDHelper.setDeviceInfo(udid: udidValue, product: product)
                    AppLogger.shared.log("通过 URL 协议抓取到 UDID: \(udidValue) (\(product ?? ""))", category: .server)
                    return
                }
            }
            return
        }

        let tempDest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempDest)
        try? FileManager.default.copyItem(at: url, to: tempDest)
        NotificationCenter.default.post(name: NSNotification.Name("SoulSignFileImportedNotification"), object: tempDest)
    }
}
