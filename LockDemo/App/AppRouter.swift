import UIKit
import AppIOSBase

final class AppRouter {
    static let shared = AppRouter()

    weak var window: UIWindow?

    private init() {}

    func start() {
        if !LockSDKSupport.hasCredentials() {
            showSetup(animated: false)
        } else if Base.isLoggedIn {
            showMain(animated: false)
        } else {
            showLogin(animated: false)
        }
    }

    func showSetup(animated: Bool = true) {
        setRoot(SetupRequiredViewController(), animated: animated)
    }

    func showLogin(animated: Bool = true) {
        let controller = Base.makeLoginViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.navigationBar.isHidden = true
        setRoot(nav, animated: animated)
    }

    func showMain(animated: Bool = true) {
        // 登录后主页 = pod 的设备列表（进面板 / 移除设备）
        let controller = Base.makeDeviceListViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.navigationBar.isHidden = false
        setRoot(nav, animated: animated)
    }

    func handleLogout(presenting: UIViewController) {
        HUD.showLoading("正在退出…")
        LockSDKSupport.logout(success: {
            HUD.hide()
            AppConfig.shared.clearSession()
            self.showLogin()
        }, failure: { message in
            HUD.hide()
            presenting.showError(message)
        })
    }

    private func setRoot(_ controller: UIViewController, animated: Bool) {
        guard let window = window else { return }
        if animated {
            UIView.transition(with: window, duration: 0.28, options: .transitionCrossDissolve) {
                window.rootViewController = controller
            }
        } else {
            window.rootViewController = controller
        }
    }
}
