import UIKit

final class HomeListViewController: ScrollStackViewController {
    private var homes: [HomeInfo] = []
    private var devices: [DeviceInfo] = []
    private var isLoading = false
    private var hasLoaded = false
    private var deviceError: String?

    override var supportsRefresh: Bool { true }

    private var currentHome: HomeInfo? {
        AppConfig.shared.selectedHome
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "门锁控制台"
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        }
        let logoutItem = UIBarButtonItem(title: "退出", style: .plain, target: self, action: #selector(logoutTapped))
        logoutItem.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                                           .foregroundColor: Theme.secondaryInk],
                                          for: .normal)
        navigationItem.rightBarButtonItem = logoutItem
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        guard AppConfig.shared.isLoggedIn else {
            AppRouter.shared.showLogin(animated: false)
            return
        }
        loadData(showSpinner: !hasLoaded)
    }

    override func handleRefresh() {
        loadData(showSpinner: false)
    }

    // MARK: - Data

    private func loadData(showSpinner: Bool) {
        guard !isLoading else { return }
        isLoading = true
        if showSpinner {
            HUD.showLoading("正在加载家庭与设备…")
        }
        LockSDKSupport.fetchHomes(success: { [weak self] items in
            guard let self = self else { return }
            self.applyHomes(items)
            self.reloadDevices { [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                self.hasLoaded = true
                if showSpinner { HUD.hide() }
                self.endRefreshing()
                self.render()
            }
        }, failure: { [weak self] message in
            guard let self = self else { return }
            self.isLoading = false
            self.hasLoaded = true
            HUD.hide()
            self.endRefreshing()
            self.render()
            self.showError(message)
        })
    }

    private func applyHomes(_ items: [[String: Any]]) {
        homes = items.compactMap { HomeInfo($0) }
        guard let current = AppConfig.shared.selectedHome else {
            if let first = homes.first {
                AppConfig.shared.selectHome(first)
            }
            return
        }
        if let matched = homes.first(where: { $0.homeId == current.homeId }) {
            AppConfig.shared.selectHome(matched)
        } else if let first = homes.first {
            AppConfig.shared.selectHome(first)
        } else {
            AppConfig.shared.selectHome(nil)
        }
    }

    private func reloadDevices(completion: @escaping () -> Void) {
        guard let home = currentHome else {
            devices = []
            deviceError = nil
            completion()
            return
        }
        LockSDKSupport.fetchDevices(withHomeId: home.homeId, success: { [weak self] items in
            self?.devices = items.compactMap { DeviceInfo($0) }
            self?.deviceError = nil
            completion()
        }, failure: { [weak self] message in
            self?.devices = []
            self?.deviceError = message
            completion()
        })
    }

    private func selectHome(_ home: HomeInfo) {
        guard currentHome?.homeId != home.homeId else { return }
        AppConfig.shared.selectHome(home)
        devices = []
        deviceError = nil
        render()
        HUD.showLoading("正在加载设备…")
        reloadDevices { [weak self] in
            HUD.hide()
            self?.toast("已切换当前家庭")
            self?.render()
        }
    }

    private func refreshDevicesOnly() {
        HUD.showLoading("正在刷新设备…")
        reloadDevices { [weak self] in
            HUD.hide()
            self?.render()
            if let error = self?.deviceError, !error.isEmpty {
                self?.showError(error)
            }
        }
    }

    // MARK: - Rendering

    private func render() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let home = currentHome
        let onlineCount = devices.filter { $0.isOnline }.count
        let banner = HeaderBanner(
            badge: "LOCK CONSOLE",
            title: home?.name ?? "未选择家庭",
            subtitle: "\(AppConfig.shared.userDisplayName) · \(home?.subtitle ?? "请创建或选择家庭")",
            accent: Theme.wifiAccent
        )
        contentStack.addArrangedSubview(banner)

        let statusCard = addCard(14)
        statusCard.spacing = 8
        statusCard.addArrangedSubview(InfoRow(key: "当前账号", value: AppConfig.shared.userDetail))
        statusCard.addArrangedSubview(InfoRow(key: "当前家庭", value: home.map { "\($0.name) (\($0.homeId))" } ?? "未选择"))
        statusCard.addArrangedSubview(InfoRow(key: "设备状态", value: "在线 \(onlineCount) / 共 \(devices.count)"))

        buildHomeSection()

        contentStack.addArrangedSubview(SectionHeaderLabel("设备"))
        if devices.isEmpty {
            let card = addCard(8)
            let empty = EmptyStateView(
                title: deviceError == nil ? "当前家庭暂无设备" : "设备加载失败",
                message: deviceError ?? "请先在下方完成配网",
                symbol: deviceError == nil ? "lock.slash" : "exclamationmark.triangle"
            )
            card.addArrangedSubview(empty)
        } else {
            for (index, device) in devices.enumerated() {
                let card = DeviceCardView(device: device, index: index)
                card.onOpen = { [weak self] in
                    self?.openDevice(device)
                }
                card.onRemove = { [weak self] in
                    self?.removeDevice(device)
                }
                contentStack.addArrangedSubview(card)
            }
        }

        buildPairingSection()

        let logout = ActionButton(title: "退出登录", style: .outline, accent: Theme.offline)
        logout.tapTarget(self, action: #selector(logoutTapped))
        contentStack.addArrangedSubview(logout)

        let footer = UILabel()
        footer.text = "涂鸦智能 App SDK · com.lock.set\nAppKey/AppSecret 仅保存在本地 LocalSecrets.plist"
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = Theme.mutedInk
        footer.textAlignment = .center
        footer.numberOfLines = 0
        contentStack.addArrangedSubview(footer)
    }

    private func buildHomeSection() {
        addSectionTitle("家庭", actionTitle: "刷新", action: { [weak self] in
            self?.loadData(showSpinner: true)
        })

        let card = addCard(12)
        if homes.isEmpty {
            card.addArrangedSubview(EmptyStateView(title: "暂无家庭，请先创建", symbol: "house"))
        } else {
            for (index, home) in homes.enumerated() {
                if index > 0 {
                    card.addArrangedSubview(separator())
                }
                let row = HomeSelectRow(home: home, selected: home.homeId == currentHome?.homeId)
                row.tag = index
                row.tapTarget(self, action: #selector(homeRowTapped(_:)))
                card.addArrangedSubview(row)
            }
        }

        let actions = UIStackView.horizontal(spacing: 10)
        let create = ActionButton(title: "创建家庭", accent: Theme.wifiAccent, height: 44)
        create.tapTarget(self, action: #selector(createHomeTapped))
        let refresh = ActionButton(title: "刷新家庭列表", style: .outline, accent: Theme.header, height: 44)
        refresh.tapTarget(self, action: #selector(refreshHomesTapped))
        actions.addArrangedSubview(create)
        actions.addArrangedSubview(refresh)
        contentStack.addArrangedSubview(actions)
    }

    private func buildPairingSection() {
        addSectionTitle("添加设备")

        let card = addCard(15)
        let hint = UILabel()
        hint.text = "选择配网方式，设备需处于配网状态。Wi-Fi 配网仅支持 2.4GHz 网络。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.mutedInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)

        let row1 = UIStackView.horizontal(spacing: 10)
        let ez = ActionButton(title: "EZ 配网", style: .tonal, accent: Theme.wifiAccent, height: 44)
        ez.tapTarget(self, action: #selector(pairEZ))
        let ap = ActionButton(title: "AP 配网", style: .tonal, accent: Theme.wifiAccent, height: 44)
        ap.tapTarget(self, action: #selector(pairAP))
        row1.addArrangedSubview(ez)
        row1.addArrangedSubview(ap)

        let row2 = UIStackView.horizontal(spacing: 10)
        let qr = ActionButton(title: "二维码配网", style: .tonal, accent: Theme.videoAccent, height: 44)
        qr.tapTarget(self, action: #selector(pairQR))
        let ble = ActionButton(title: "蓝牙配网", style: .tonal, accent: Theme.bleAccent, height: 44)
        ble.tapTarget(self, action: #selector(pairBLE))
        row2.addArrangedSubview(qr)
        row2.addArrangedSubview(ble)

        card.addArrangedSubview(row1)
        card.addArrangedSubview(row2)
    }

    // MARK: - Actions

    @objc private func homeRowTapped(_ sender: UIControl) {
        guard sender.tag >= 0, sender.tag < homes.count else { return }
        selectHome(homes[sender.tag])
    }

    @objc private func createHomeTapped() {
        prompt(title: "创建家庭",
               message: "输入家庭名称，创建后自动设为当前家庭。",
               placeholder: "例如：我的家") { [weak self] name in
            guard !name.isEmpty else {
                self?.toast("请输入家庭名称")
                return
            }
            HUD.showLoading("正在创建家庭…")
            LockSDKSupport.createHome(withName: name, success: { [weak self] result in
                HUD.hide()
                if let dict = result as? [String: Any], let home = HomeInfo(dict) {
                    AppConfig.shared.selectHome(home)
                }
                self?.toast("创建家庭成功")
                self?.loadData(showSpinner: false)
            }, failure: { [weak self] message in
                HUD.hide()
                self?.showError(message)
            })
        }
    }

    @objc private func refreshHomesTapped() {
        loadData(showSpinner: true)
    }

    @objc private func logoutTapped() {
        showConfirm(title: "退出登录",
                    message: "退出后需要重新登录才能访问家庭与设备。",
                    confirmTitle: "退出",
                    destructive: true) {
            AppRouter.shared.handleLogout(presenting: self)
        }
    }

    private func openDevice(_ device: DeviceInfo) {
        guard let panel = DevicePanelFactory.make(device: device) else {
            showAlert(title: "不支持的门锁类型",
                      message: "该设备无法打开门锁面板。\n\n\(device.meta)")
            return
        }
        navigationController?.pushViewController(panel, animated: true)
    }

    private func removeDevice(_ device: DeviceInfo) {
        showConfirm(title: "移除设备",
                    message: "确定从当前家庭移除「\(device.name)」？移除后需重新配网才能使用。",
                    confirmTitle: "移除",
                    destructive: true) { [weak self] in
            HUD.showLoading("正在移除…")
            LockSDKSupport.removeDevice(withDevId: device.devId, success: {
                HUD.hide()
                self?.toast("设备已移除")
                self?.refreshDevicesOnly()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.showError(message)
            })
        }
    }

    private func pushPairing(mode: LockPairingMode) {
        guard let home = currentHome else {
            toast("请先创建或选择家庭")
            return
        }
        navigationController?.pushViewController(PairingViewController(home: home, initialMode: mode), animated: true)
    }

    @objc private func pairEZ() { pushPairing(mode: .ez) }
    @objc private func pairAP() { pushPairing(mode: .ap) }
    @objc private func pairQR() { pushPairing(mode: .qr) }
    @objc private func pairBLE() { pushPairing(mode: .ble) }
}

final class HomeSelectRow: UIControl {
    init(home: HomeInfo, selected: Bool) {
        super.init(frame: .zero)

        let name = UILabel()
        name.text = home.name
        name.font = .systemFont(ofSize: 15, weight: selected ? .semibold : .medium)
        name.textColor = selected ? Theme.wifiAccent : Theme.ink

        let subtitle = UILabel()
        subtitle.text = home.subtitle
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = Theme.mutedInk

        let text = UIStackView.vertical(spacing: 3)
        text.addArrangedSubview(name)
        text.addArrangedSubview(subtitle)

        let check = UIImageView(image: UIImage(systemName: selected ? "checkmark.circle.fill" : "circle"))
        check.tintColor = selected ? Theme.wifiAccent : Theme.hairline
        check.contentMode = .scaleAspectFit
        check.translatesAutoresizingMaskIntoConstraints = false
        check.widthAnchor.constraint(equalToConstant: 21).isActive = true
        check.heightAnchor.constraint(equalToConstant: 21).isActive = true

        let row = UIStackView.horizontal(spacing: 10)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(text)
        row.addArrangedSubview(check)
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 10, left: 2, bottom: 10, right: 2))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}

final class DeviceCardView: UIView {
    var onOpen: (() -> Void)?
    var onRemove: (() -> Void)?

    init(device: DeviceInfo, index: Int) {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = 16
        layer.masksToBounds = true
        let accent = Theme.accent(for: device.kind)

        let iconBackground = UIView()
        iconBackground.backgroundColor = accent.withAlphaComponent(0.12)
        iconBackground.layer.cornerRadius = 12
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 44),
            iconBackground.heightAnchor.constraint(equalToConstant: 44)
        ])
        let icon = UIImageView(image: UIImage(systemName: device.kind.symbolName))
        icon.tintColor = accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22)
        ])

        let name = UILabel()
        name.text = device.name
        name.font = .systemFont(ofSize: 16, weight: .semibold)
        name.textColor = Theme.ink
        name.numberOfLines = 2

        let badges = UIStackView.horizontal(spacing: 6)
        badges.addArrangedSubview(PillLabel(text: device.kind.title,
                                            color: accent,
                                            background: accent.withAlphaComponent(0.1)))
        let onlineColor = device.isOnline ? Theme.online : Theme.offline
        badges.addArrangedSubview(PillLabel(text: device.isOnline ? "在线" : "离线",
                                            color: onlineColor,
                                            background: onlineColor.withAlphaComponent(0.1)))
        badges.addArrangedSubview(UIView())

        let titleStack = UIStackView.vertical(spacing: 6)
        titleStack.addArrangedSubview(name)
        titleStack.addArrangedSubview(badges)

        let header = UIStackView.horizontal(spacing: 12)
        header.addArrangedSubview(iconBackground)
        header.addArrangedSubview(titleStack)

        let meta = UILabel()
        meta.text = device.meta
        meta.font = .systemFont(ofSize: 11)
        meta.textColor = Theme.mutedInk
        meta.numberOfLines = 3

        let divider = UIView()
        divider.backgroundColor = Theme.hairline
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let open = ActionButton(title: "打开面板", style: .tonal, accent: accent, height: 40)
        open.tapTarget(self, action: #selector(openTapped))
        let remove = ActionButton(title: "移除", style: .outline, accent: Theme.offline, height: 40)
        remove.tapTarget(self, action: #selector(removeTapped))
        NSLayoutConstraint.activate([
            remove.widthAnchor.constraint(equalToConstant: 76)
        ])
        let actions = UIStackView.horizontal(spacing: 10)
        actions.addArrangedSubview(open)
        actions.addArrangedSubview(remove)

        let stack = UIStackView.vertical(spacing: 10)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(meta)
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(actions)
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func openTapped() { onOpen?() }
    @objc private func removeTapped() { onRemove?() }
}

enum DevicePanelFactory {
    static func make(device: DeviceInfo) -> UIViewController? {
        let homeId = device.homeId > 0 ? device.homeId : (AppConfig.shared.selectedHome?.homeId ?? 0)
        switch device.kind {
        case .wifi:
            return WifiLockPanelViewController(device: device)
        case .video, .photo:
            return VideoLockPanelViewController(device: device)
        case .ble:
            return BLELockPanelViewController(device: device, homeId: homeId)
        case .other:
            return nil
        }
    }
}
