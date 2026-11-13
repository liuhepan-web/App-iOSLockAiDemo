import UIKit
import ThingSmartHomeKit
import AppIOSBase

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Theme.configureNavigationBar()

        // SDK 初始化交给 MiniPanelBase（AppKey/AppSecret 来自本地 LocalSecrets.plist）
        configureTuyaSDK()

        // 设备列表点击设备 → 跳本 Demo 的原生锁面板（不依赖面板业务包）
        Base.devicePanelHandler = { device, nav in
            let dict: [String: Any] = [
                "devId": device.devId ?? "",
                "name": device.name ?? "",
                "categoryCode": device.categoryCode ?? "",
                "productId": device.productId ?? "",
                "homeId": device.homeId,
                "isOnline": device.isOnline,
                "kind": LockSDKSupport.deviceKind(forCategoryCode: device.categoryCode,
                                                  productId: device.productId)
            ]
            guard let info = DeviceInfo(dict),
                  let panel = DevicePanelFactory.make(device: info) else {
                let alert = UIAlertController(title: "不支持的门锁类型",
                                              message: "「\(device.name ?? device.devId ?? "未知设备")」暂无原生面板",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                nav?.present(alert, animated: true)
                return
            }
            nav?.pushViewController(panel, animated: true)
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = Theme.background
        self.window = window
        AppRouter.shared.window = window

        AppRouter.shared.start()
        window.makeKeyAndVisible()

        // 登录成功后由 Base 发送 .baseDidLogin，切到主页
        NotificationCenter.default.addObserver(
            forName: .baseDidLogin, object: nil, queue: .main
        ) { _ in
            AppRouter.shared.showMain()
        }

        // 退出登录后由 Base 发送 .baseDidLogout，切回登录页
        NotificationCenter.default.addObserver(
            forName: .baseDidLogout, object: nil, queue: .main
        ) { _ in
            AppRouter.shared.showLogin()
        }
        return true
    }

    private func configureTuyaSDK() {
        let secrets = Bundle.main.path(forResource: "LocalSecrets", ofType: "plist")
            .flatMap { NSDictionary(contentsOfFile: $0) }
        let appKey = (secrets?["AppKey"] as? String) ?? ""
        let appSecret = (secrets?["AppSecret"] as? String) ?? ""
        guard !appKey.isEmpty else { return }
        ThingSmartSDK.sharedInstance().debugMode = true
        Base.configure(appKey: appKey, appSecret: appSecret)
    }
}
