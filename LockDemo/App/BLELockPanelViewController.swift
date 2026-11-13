import UIKit

final class BLELockPanelViewController: ScrollStackViewController {
    private enum State {
        case offline
        case bleConnected
        case gatewayOnline

        var title: String {
            switch self {
            case .offline: return "离线"
            case .bleConnected: return "蓝牙已连接"
            case .gatewayOnline: return "网关在线"
            }
        }

        var color: UIColor {
            switch self {
            case .offline: return Theme.offline
            case .bleConnected, .gatewayOnline: return Theme.online
            }
        }

        var hint: String {
            switch self {
            case .offline: return "请靠近门锁并点击「连接蓝牙」，或确认网关在线。"
            case .bleConnected: return "已通过蓝牙直连门锁，可执行开锁、上锁与同步。"
            case .gatewayOnline: return "门锁通过网关在线，可远程下发开锁与上锁指令。"
            }
        }
    }

    private let device: DeviceInfo
    private let homeId: Int64
    private lazy var bleService = LockBLEService(devId: device.devId, homeId: homeId)

    private let headerView: LockPanelHeaderView
    private let stateLabel = UILabel()
    private let statePill = PillLabel(text: "离线", color: Theme.offline, background: Theme.offline.withAlphaComponent(0.1))
    private let stateHint = UILabel()
    private let proLabel = UILabel()
    private let memberCountLabel = UILabel()
    private let memberHintLabel = UILabel()

    private var connectButton: ActionButton?
    private var unlockTile: LockActionTile?
    private var lockTile: LockActionTile?
    private var syncTile: LockActionTile?
    private var stateTimer: Timer?
    private var isBusy = false
    private var isLoadingMembers = false
    private var isPro = false

    override var supportsRefresh: Bool { true }

    init(device: DeviceInfo, homeId: Int64) {
        self.device = device
        self.homeId = homeId > 0 ? homeId : (AppConfig.shared.selectedHome?.homeId ?? 0)
        self.headerView = LockPanelHeaderView(device: device)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stateTimer?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = device.name
        buildHeader()
        buildStateCard()
        buildActions()
        buildMemberCard()
        buildPasswordCard()
        buildHintCard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bleService.autoConnect()
        refreshState()
        loadMembers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startStateTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stateTimer?.invalidate()
        stateTimer = nil
    }

    override func handleRefresh() {
        refreshState()
        loadMembers()
        endRefreshing()
    }

    // MARK: - UI

    private func buildHeader() {
        contentStack.addArrangedSubview(headerView)

        let card = addCard(14)
        card.spacing = 9
        card.addArrangedSubview(InfoRow(key: "设备类型", value: device.kind.title))
        card.addArrangedSubview(InfoRow(key: "devId", value: device.devId))
        card.addArrangedSubview(InfoRow(key: "categoryCode", value: device.categoryCode.isEmpty ? "-" : device.categoryCode))
        card.addArrangedSubview(InfoRow(key: "productId", value: device.productId.isEmpty ? "-" : device.productId))

        let proKey = UILabel()
        proKey.text = "成员体系"
        proKey.font = .systemFont(ofSize: 13)
        proKey.textColor = Theme.mutedInk
        proLabel.text = "检测中…"
        proLabel.font = .systemFont(ofSize: 13, weight: .medium)
        proLabel.textColor = Theme.secondaryInk
        proLabel.textAlignment = .right
        let proRow = UIStackView.horizontal(spacing: 12)
        proRow.addArrangedSubview(proKey)
        proRow.addArrangedSubview(UIView())
        proRow.addArrangedSubview(proLabel)
        card.addArrangedSubview(proRow)
    }

    private func buildStateCard() {
        addSectionTitle("连接状态")
        let card = addCard(16)

        let title = UILabel()
        title.text = "门锁状态"
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = Theme.ink

        let headerRow = UIStackView.horizontal(spacing: 8)
        headerRow.addArrangedSubview(title)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(statePill)
        card.addArrangedSubview(headerRow)

        stateLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        stateLabel.textColor = Theme.secondaryInk
        stateLabel.text = "正在检测…"
        card.addArrangedSubview(stateLabel)

        stateHint.font = .systemFont(ofSize: 12)
        stateHint.textColor = Theme.mutedInk
        stateHint.numberOfLines = 0
        stateHint.text = "门锁支持蓝牙直连；在线时也可通过网关下发指令。"
        card.addArrangedSubview(stateHint)

        let connect = ActionButton(title: "连接蓝牙", accent: Theme.bleAccent, height: 44)
        connect.tapTarget(self, action: #selector(connectTapped))
        card.addArrangedSubview(connect)
        connectButton = connect
    }

    private func buildActions() {
        addSectionTitle("快捷操作")

        let unlock = LockActionTile(title: "开锁",
                                    subtitle: "蓝牙直连或远程开锁",
                                    symbol: "lock.open",
                                    accent: Theme.bleAccent)
        unlock.onTap { [weak self] in
            self?.unlockTapped()
        }
        unlockTile = unlock

        let lock = LockActionTile(title: "上锁",
                                  subtitle: "蓝牙直连或远程上锁",
                                  symbol: "lock",
                                  accent: Theme.bleAccent)
        lock.onTap { [weak self] in
            self?.lockTapped()
        }
        lockTile = lock

        let sync = LockActionTile(title: "同步数据",
                                  subtitle: "同步成员与开锁记录",
                                  symbol: "arrow.triangle.2.circlepath",
                                  accent: Theme.header)
        sync.onTap { [weak self] in
            self?.syncTapped()
        }
        syncTile = sync

        let passwords = LockActionTile(title: "密码管理",
                                       subtitle: "动态 / 离线 / 在线密码",
                                       symbol: "key",
                                       accent: Theme.header)
        passwords.onTap { [weak self] in
            guard let self = self else { return }
            self.navigationController?.pushViewController(
                BLEPasswordViewController(device: self.device, homeId: self.homeId),
                animated: true
            )
        }

        addTileGrid([unlock, lock, sync, passwords])
    }

    private func buildMemberCard() {
        addSectionTitle("成员")

        memberCountLabel.text = "正在加载成员…"
        memberCountLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        memberCountLabel.textColor = Theme.ink

        memberHintLabel.text = "Pro 门锁支持成员邀请与管理；标准门锁仅支持查看当前成员。"
        memberHintLabel.font = .systemFont(ofSize: 12)
        memberHintLabel.textColor = Theme.mutedInk
        memberHintLabel.numberOfLines = 0

        let card = addCard(16)
        card.addArrangedSubview(memberCountLabel)
        card.addArrangedSubview(memberHintLabel)

        let row = UIStackView.horizontal(spacing: 10)
        let refresh = ActionButton(title: "刷新成员", style: .outline, accent: Theme.header, height: 44)
        refresh.tapTarget(self, action: #selector(refreshMembersTapped))
        let manage = ActionButton(title: "管理成员", style: .tonal, accent: Theme.bleAccent, height: 44)
        manage.tapTarget(self, action: #selector(manageMembersTapped))
        row.addArrangedSubview(refresh)
        row.addArrangedSubview(manage)
        card.addArrangedSubview(row)
    }

    private func buildPasswordCard() {
        addSectionTitle("密码管理")
        let card = addCard(14)
        let label = UILabel()
        label.text = "支持获取动态密码、生成 7 天离线密码，以及 4–15 位在线临时密码。离线密码需在门锁旁通过蓝牙同步后生效。"
        label.font = .systemFont(ofSize: 12)
        label.textColor = Theme.secondaryInk
        label.numberOfLines = 0
        card.addArrangedSubview(label)

        let button = ActionButton(title: "打开密码管理", style: .tonal, accent: Theme.bleAccent, height: 44)
        button.tapTarget(self, action: #selector(passwordTapped))
        card.addArrangedSubview(button)
    }

    private func buildHintCard() {
        let card = addCard(14)
        let label = UILabel()
        label.text = "蓝牙门锁的本地操作需要手机靠近门锁。若处于离线状态，请先连接蓝牙；远程操作需要门锁通过网关在线。"
        label.font = .systemFont(ofSize: 11)
        label.textColor = Theme.mutedInk
        label.numberOfLines = 0
        card.addArrangedSubview(label)
    }

    // MARK: - State

    private func startStateTimer() {
        guard stateTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
        RunLoop.main.add(timer, forMode: .common)
        stateTimer = timer
    }

    private func currentState() -> State {
        let connected = bleService.isBLEConnected()
        let online = bleService.isOnline()
        if connected { return .bleConnected }
        if online { return .gatewayOnline }
        return .offline
    }

    private func refreshState() {
        let state = currentState()
        let connected = bleService.isBLEConnected()
        let online = bleService.isOnline()

        headerView.updateOnline(connected || online)
        statePill.text = state.title
        statePill.backgroundColor = state.color.withAlphaComponent(0.1)
        statePill.textColor = state.color
        stateLabel.text = "当前状态：\(state.title)"
        stateLabel.textColor = state.color
        stateHint.text = state.hint

        connectButton?.updateTitle(connected ? "蓝牙已连接" : "连接蓝牙")
        connectButton?.isEnabled = !connected && !isBusy
        unlockTile?.isEnabled = (connected || online) && !isBusy
        lockTile?.isEnabled = (connected || online) && !isBusy
        syncTile?.isEnabled = (connected || online) && !isBusy
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        let available = bleService.isBLEConnected() || bleService.isOnline()
        unlockTile?.isEnabled = !busy && available
        lockTile?.isEnabled = !busy && available
        syncTile?.isEnabled = !busy && available
        connectButton?.isEnabled = !busy && !bleService.isBLEConnected()
    }

    // MARK: - Data

    private func loadMembers() {
        guard !isLoadingMembers else { return }
        isLoadingMembers = true
        bleService.fetchMembers(success: { [weak self] members, proDevice in
            guard let self = self else { return }
            self.isLoadingMembers = false
            self.isPro = proDevice
            self.proLabel.text = proDevice ? "Pro 门锁" : "标准门锁"
            self.memberCountLabel.text = proDevice
                ? "共 \(members.count) 位成员"
                : "当前成员 \(members.count) 位"
            self.memberHintLabel.text = proDevice
                ? "Pro 门锁支持邀请成员，并为成员添加开锁密码。"
                : "标准门锁仅支持查看当前成员，不能创建或删除成员。"
        }, failure: { [weak self] message in
            guard let self = self else { return }
            self.isLoadingMembers = false
            self.memberCountLabel.text = "成员加载失败"
            self.memberHintLabel.text = message
        })
    }

    // MARK: - Actions

    @objc private func connectTapped() {
        guard !isBusy else { return }
        setBusy(true)
        HUD.showLoading("正在连接蓝牙门锁…")
        bleService.connect(withTimeout: 20) { [weak self] connected, message in
            HUD.hide()
            guard let self = self else { return }
            self.setBusy(false)
            self.refreshState()
            if connected {
                self.toast("蓝牙已连接")
                self.loadMembers()
            } else {
                self.showError(message)
            }
        }
    }

    private func unlockTapped() {
        guard !isBusy else { return }
        let state = currentState()
        guard state != .offline else {
            showAlert(title: "门锁离线", message: "请先连接蓝牙，或等待门锁通过网关上线。")
            return
        }
        setBusy(true)
        HUD.showLoading(state == .bleConnected ? "正在蓝牙开锁…" : "正在远程开锁…")
        bleService.unlock(success: { [weak self] in
            HUD.hide()
            guard let self = self else { return }
            self.setBusy(false)
            self.refreshState()
            self.toast("开锁指令已发送")
        }, failure: { [weak self] message in
            HUD.hide()
            guard let self = self else { return }
            self.setBusy(false)
            self.refreshState()
            self.showError(message)
        })
    }

    private func lockTapped() {
        guard !isBusy else { return }
        let state = currentState()
        guard state != .offline else {
            showAlert(title: "门锁离线", message: "请先连接蓝牙，或等待门锁通过网关上线。")
            return
        }
        setBusy(true)
        HUD.showLoading(state == .bleConnected ? "正在蓝牙上锁…" : "正在远程上锁…")
        bleService.lock(success: { [weak self] in
            HUD.hide()
            guard let self = self else { return }
            self.setBusy(false)
            self.refreshState()
            self.toast("上锁指令已发送")
        }, failure: { [weak self] message in
            HUD.hide()
            guard let self = self else { return }
            self.setBusy(false)
            self.refreshState()
            self.showError(message)
        })
    }

    private func syncTapped() {
        guard !isBusy else { return }
        setBusy(true)
        HUD.showLoading("正在同步门锁数据…")
        bleService.syncData(success: { [weak self] in
            HUD.hide()
            guard let self = self else { return }
            self.setBusy(false)
            self.refreshState()
            self.toast("同步指令已发送")
        }, failure: { [weak self] message in
            HUD.hide()
            guard let self = self else { return }
            self.setBusy(false)
            self.refreshState()
            self.showError(message)
        })
    }

    @objc private func refreshMembersTapped() {
        HUD.showLoading("正在刷新成员…")
        bleService.fetchMembers(success: { [weak self] members, proDevice in
            HUD.hide()
            guard let self = self else { return }
            self.isPro = proDevice
            self.proLabel.text = proDevice ? "Pro 门锁" : "标准门锁"
            self.memberCountLabel.text = proDevice
                ? "共 \(members.count) 位成员"
                : "当前成员 \(members.count) 位"
            self.toast("成员已刷新")
        }, failure: { [weak self] message in
            HUD.hide()
            self?.showError(message)
        })
    }

    @objc private func manageMembersTapped() {
        navigationController?.pushViewController(
            MemberListViewController(device: device, kind: .ble, homeId: homeId),
            animated: true
        )
    }

    @objc private func passwordTapped() {
        navigationController?.pushViewController(
            BLEPasswordViewController(device: device, homeId: homeId),
            animated: true
        )
    }
}
