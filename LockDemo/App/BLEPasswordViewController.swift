import UIKit

final class BLEPasswordViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private let homeId: Int64
    private lazy var bleService = LockBLEService(devId: device.devId, homeId: homeId)

    private let dynamicRow = SecretValueRow(title: "当前动态密码", placeholder: "点击下方按钮获取")
    private let offlineNameField = FormField(title: "离线密码名称", placeholder: "例如：长期访客")
    private let onlineNameField = FormField(title: "在线密码名称", placeholder: "例如：临时保洁")
    private let onlinePasswordField = FormField(title: "在线密码", placeholder: "4–15 位字母或数字", keyboardType: .asciiCapable)
    private let latestRow = SecretValueRow(title: "最近生成的密码", placeholder: "创建成功后显示")
    private let latestCard = CardView(padding: 16)
    private let listStack = UIStackView.vertical(spacing: 8)
    private let summaryLabel = UILabel()
    private let proHintLabel = UILabel()
    private var passwords: [PasswordInfo] = []
    private var isLoading = false
    private var isPro = false
    private var proDetected = false
    private var dynamicButton: ActionButton?
    private var offlineButton: ActionButton?
    private var onlineButton: ActionButton?

    override var supportsRefresh: Bool { true }

    init(device: DeviceInfo, homeId: Int64) {
        self.device = device
        self.homeId = homeId > 0 ? homeId : (AppConfig.shared.selectedHome?.homeId ?? 0)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "密码管理"
        buildDynamicCard()
        buildOfflineCard()
        buildOnlineCard()
        buildLatestCard()
        buildListCard()
        detectPro()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPasswords()
    }

    override func handleRefresh() {
        loadPasswords()
        endRefreshing()
    }

    // MARK: - UI

    private func buildDynamicCard() {
        addSectionTitle("动态密码")
        let card = addCard(16)
        card.addArrangedSubview(dynamicRow)

        let button = ActionButton(title: "获取动态密码", accent: Theme.bleAccent)
        button.tapTarget(self, action: #selector(fetchDynamic))
        card.addArrangedSubview(button)
        dynamicButton = button

        let hint = UILabel()
        hint.text = "动态密码由门锁实时生成，适用于临时开门。"
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = Theme.mutedInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)
    }

    private func buildOfflineCard() {
        addSectionTitle("离线临时密码")
        let card = addCard(16)

        let hint = UILabel()
        hint.text = "生成 7 天有效的离线密码，可多次使用。创建后需在门锁旁通过蓝牙同步至门锁。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.secondaryInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)
        card.addArrangedSubview(offlineNameField)

        let button = ActionButton(title: "生成离线密码", accent: Theme.bleAccent)
        button.tapTarget(self, action: #selector(createOffline))
        card.addArrangedSubview(button)
        offlineButton = button
    }

    private func buildOnlineCard() {
        addSectionTitle("在线临时密码")
        let card = addCard(16)

        let hint = UILabel()
        hint.text = "自定义 4–15 位在线密码，创建后 24 小时内有效，可多次使用。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.secondaryInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)
        card.addArrangedSubview(onlineNameField)
        card.addArrangedSubview(onlinePasswordField)

        let button = ActionButton(title: "创建在线密码", accent: Theme.bleAccent)
        button.tapTarget(self, action: #selector(createOnline))
        card.addArrangedSubview(button)
        onlineButton = button
    }

    private func buildLatestCard() {
        latestCard.isHidden = true
        let stack = UIStackView.vertical(spacing: 8)
        latestCard.contentView().addSubview(stack)
        stack.pinEdges(to: latestCard.contentView())
        stack.addArrangedSubview(latestRow)
        contentStack.addArrangedSubview(latestCard)
    }

    private func buildListCard() {
        addSectionTitle("密码列表", actionTitle: "刷新", action: { [weak self] in
            self?.loadPasswords()
        })

        proHintLabel.font = .systemFont(ofSize: 12)
        proHintLabel.textColor = Theme.secondaryInk
        proHintLabel.numberOfLines = 0
        proHintLabel.text = "正在检测门锁类型…"

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        summaryLabel.textColor = Theme.secondaryInk
        summaryLabel.numberOfLines = 0
        summaryLabel.text = "正在加载…"

        let card = addCard(16)
        card.addArrangedSubview(proHintLabel)
        card.addArrangedSubview(summaryLabel)
        card.addArrangedSubview(listStack)
    }

    // MARK: - Data

    private func detectPro() {
        bleService.detectPro { [weak self] pro in
            guard let self = self else { return }
            self.isPro = pro
            self.proDetected = true
            self.proHintLabel.text = pro
                ? "当前为 Pro 门锁，密码列表来自 Pro 密码体系。"
                : "当前为标准门锁，展示在线与离线密码列表。"
        }
    }

    private func loadPasswords() {
        guard !isLoading else { return }
        isLoading = true
        summaryLabel.text = "正在加载密码…"
        bleService.fetchPasswords(success: { [weak self] items in
            guard let self = self else { return }
            self.isLoading = false
            self.passwords = items.map { PasswordInfo($0) }
            self.renderPasswords()
        }, failure: { [weak self] message in
            guard let self = self else { return }
            self.isLoading = false
            self.passwords = []
            self.listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.summaryLabel.text = "加载失败：\(message)"
        })
    }

    private func renderPasswords() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryLabel.text = passwords.isEmpty ? "暂无临时密码" : "共 \(passwords.count) 条密码"
        guard !passwords.isEmpty else {
            listStack.addArrangedSubview(
                EmptyStateView(title: "暂无临时密码",
                               message: "可在上方生成离线密码或在线密码。",
                               symbol: "key")
            )
            return
        }
        for password in passwords {
            listStack.addArrangedSubview(makePasswordRow(password))
        }
    }

    private func makePasswordRow(_ password: PasswordInfo) -> UIView {
        let row = UIView()
        row.backgroundColor = Theme.fieldBackground
        row.layer.cornerRadius = Theme.controlRadius

        let name = UILabel()
        name.text = password.name
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.textColor = Theme.ink

        let typePill = PillLabel(text: password.type,
                                 color: Theme.bleAccent,
                                 background: Theme.bleAccent.withAlphaComponent(0.1))
        let header = UIStackView.horizontal(spacing: 8)
        header.addArrangedSubview(name)
        header.addArrangedSubview(typePill)
        header.addArrangedSubview(UIView())

        let detail = UILabel()
        var parts: [String] = []
        if !password.code.isEmpty { parts.append("密码 \(password.code)") }
        if password.identifier > 0 { parts.append("编号 \(password.identifier)") }
        if password.sn > 0 { parts.append("SN \(password.sn)") }
        parts.append(password.validity)
        detail.text = parts.joined(separator: " · ")
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = Theme.mutedInk
        detail.numberOfLines = 3

        let stack = UIStackView.vertical(spacing: 6)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(detail)
        row.addSubview(stack)
        stack.pinEdges(to: row, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        return row
    }

    private func showLatest(_ password: String) {
        guard !password.isEmpty else { return }
        latestRow.setValue(password)
        latestCard.isHidden = false
        UIPasteboard.general.string = password
    }

    // MARK: - Actions

    @objc private func fetchDynamic() {
        dynamicButton?.isEnabled = false
        HUD.showLoading("正在获取动态密码…")
        bleService.fetchDynamicPassword(success: { [weak self] password in
            HUD.hide()
            self?.dynamicButton?.isEnabled = true
            guard let self = self else { return }
            guard !password.isEmpty else {
                self.toast("未获取到动态密码")
                return
            }
            self.dynamicRow.setValue(password)
            UIPasteboard.general.string = password
            self.toast("动态密码已获取并复制")
        }, failure: { [weak self] message in
            HUD.hide()
            self?.dynamicButton?.isEnabled = true
            self?.showError(message)
        })
    }

    @objc private func createOffline() {
        var name = offlineNameField.text
        if name.isEmpty {
            name = "offline"
            offlineNameField.text = name
        }
        offlineButton?.isEnabled = false
        HUD.showLoading("正在生成离线密码…")
        bleService.createOfflinePassword(withName: name, success: { [weak self] password in
            HUD.hide()
            guard let self = self else { return }
            self.offlineButton?.isEnabled = true
            self.showLatest(password)
            self.presentCopiedPassword(title: "离线密码已生成",
                                       password: password,
                                       message: "有效期 7 天，请靠近门锁并通过蓝牙同步。")
            self.loadPasswords()
        }, failure: { [weak self] message in
            HUD.hide()
            self?.offlineButton?.isEnabled = true
            self?.showError(message)
        })
    }

    @objc private func createOnline() {
        var name = onlineNameField.text
        let password = onlinePasswordField.text
        guard password.count >= 4, password.count <= 15 else {
            toast("请输入 4–15 位在线密码")
            return
        }
        if name.isEmpty {
            name = "online"
            onlineNameField.text = name
        }
        onlineButton?.isEnabled = false
        HUD.showLoading("正在创建在线密码…")
        bleService.createOnlinePassword(withName: name, password: password, success: { [weak self] result in
            HUD.hide()
            guard let self = self else { return }
            self.onlineButton?.isEnabled = true
            let display = result.isEmpty ? password : result
            self.showLatest(display)
            self.presentCopiedPassword(title: "在线密码已创建",
                                       password: display,
                                       message: "有效期 24 小时，可多次使用。")
            self.onlinePasswordField.text = ""
            self.loadPasswords()
        }, failure: { [weak self] message in
            HUD.hide()
            self?.onlineButton?.isEnabled = true
            self?.showError(message)
        })
    }
}
