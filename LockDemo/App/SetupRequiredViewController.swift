import UIKit

final class SetupRequiredViewController: ScrollStackViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let banner = HeaderBanner(
            badge: "SDK 配置待完成",
            title: "涂鸦门锁",
            subtitle: "需要 AppKey / AppSecret 与匹配包名的安全算法包后才能启动。",
            accent: Theme.wifiAccent
        )
        contentStack.addArrangedSubview(banner)

        let card = addCard(18)
        card.addArrangedSubview(SectionHeaderLabel("接入步骤"))
        let steps = [
            "1. 在涂鸦 IoT 平台创建应用，包名填写 com.lock.set，下载对应 iOS 安全图片/算法包。",
            "2. 将 ios_core_sdk 放入 TuyaSDK/ios_core_sdk，并执行 pod install。",
            "3. 复制 LocalSecrets.example.plist 为 LocalSecrets.plist，填入 AppKey 与 AppSecret。",
            "4. 重新构建并启动 App。密钥文件不会纳入版本控制。"
        ]
        steps.forEach { step in
            let label = UILabel()
            label.text = step
            label.font = .systemFont(ofSize: 14)
            label.textColor = Theme.secondaryInk
            label.numberOfLines = 0
            card.addArrangedSubview(label)
        }

        let retry = ActionButton(title: "重新检测配置", accent: Theme.wifiAccent)
        retry.tapTarget(self, action: #selector(retryTapped))
        contentStack.addArrangedSubview(retry)

        let hint = UILabel()
        hint.text = "如仍无法启动，请确认 LocalSecrets.plist 已加入 App Bundle，且 AppKey/AppSecret 不是示例占位符。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.mutedInk
        hint.numberOfLines = 0
        contentStack.addArrangedSubview(hint)
    }

    @objc private func retryTapped() {
        if LockSDKSupport.configureSDK() {
            AppRouter.shared.start()
        } else {
            toast("仍未检测到有效配置，请检查 LocalSecrets.plist 与安全算法包")
        }
    }
}
