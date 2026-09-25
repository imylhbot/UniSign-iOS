import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabBarController()
        self.window = window
        window.makeKeyAndVisible()
        
        // Handle opened IPA file if launched via "Open in SoulSign" or URL Scheme
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
        if scheme == "soulsign" || scheme == "unisign" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if let udidItem = components.queryItems?.first(where: { $0.name.lowercased() == "udid" }),
                   let udidValue = udidItem.value, !udidValue.isEmpty {
                    DeviceInfoHelper.setCustomUDID(udidValue)
                    NotificationCenter.default.post(name: NSNotification.Name("UniSignUDIDUpdatedNotification"), object: nil)
                    print("[SoulSign] 成功从 URL Scheme 接收并同步设备真机 UDID: \(udidValue)")
                    return
                }
            }
            return
        }
        
        // Automatically imports incoming IPA or P12 into the Documents sandbox
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)
        print("[SoulSign] Imported file via AirDrop / Share Sheet: \(dest.path)")
    }
}
