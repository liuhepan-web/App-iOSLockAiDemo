import UIKit

final class LockPanelHeaderView: UIView {
    private let badgePill = PillLabel(text: nil, color: .white, background: UIColor.white.withAlphaComponent(0.13))
    private let statusPill = PillLabel(text: "在线", color: .white, background: Theme.online)
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()

    init(device: DeviceInfo) {
        super.init(frame: .zero)
        backgroundColor = Theme.header
        layer.cornerRadius = 22
        layer.masksToBounds = true
        let accent = Theme.accent(for: device.kind)

        badgePill.text = device.kind.badge

        let iconBackground = UIView()
        iconBackground.backgroundColor = accent.withAlphaComponent(0.28)
        iconBackground.layer.cornerRadius = 14
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 48),
            iconBackground.heightAnchor.constraint(equalToConstant: 48)
        ])
        let icon = UIImageView(image: UIImage(systemName: device.kind.symbolName))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 23),
            icon.heightAnchor.constraint(equalToConstant: 23)
        ])

        titleLabel.text = device.name
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        metaLabel.text = "\(device.kind.title) · \(device.devId)"
        metaLabel.font = .systemFont(ofSize: 12)
        metaLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        metaLabel.numberOfLines = 2

        let textStack = UIStackView.vertical(spacing: 6)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(metaLabel)

        let mainRow = UIStackView.horizontal(spacing: 13, alignment: .center)
        mainRow.addArrangedSubview(iconBackground)
        mainRow.addArrangedSubview(textStack)

        let badgeRow = UIStackView.horizontal(spacing: 8)
        badgeRow.addArrangedSubview(badgePill)
        badgeRow.addArrangedSubview(UIView())
        badgeRow.addArrangedSubview(statusPill)

        let stack = UIStackView.vertical(spacing: 14)
        stack.addArrangedSubview(badgeRow)
        stack.addArrangedSubview(mainRow)
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 16, left: 18, bottom: 18, right: 18))

        updateOnline(device.isOnline)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateOnline(_ online: Bool) {
        statusPill.text = online ? "在线" : "离线"
        statusPill.backgroundColor = online ? Theme.online : Theme.offline
    }

    func updateBadge(_ text: String) {
        badgePill.text = text
    }

    func updateMeta(_ text: String) {
        metaLabel.text = text
    }
}

final class LockActionTile: UIControl {
    private var tapAction: (() -> Void)?

    init(title: String, subtitle: String, symbol: String, accent: UIColor) {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = 16
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = Theme.hairline.cgColor

        let iconBackground = UIView()
        iconBackground.backgroundColor = accent.withAlphaComponent(0.12)
        iconBackground.layer.cornerRadius = 10
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 38),
            iconBackground.heightAnchor.constraint(equalToConstant: 38)
        ])
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 19),
            icon.heightAnchor.constraint(equalToConstant: 19)
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = Theme.ink
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = Theme.mutedInk
        subtitleLabel.numberOfLines = 2

        let stack = UIStackView.vertical(spacing: 7)
        stack.addArrangedSubview(iconBackground)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 10))

        heightAnchor.constraint(equalToConstant: 122).isActive = true
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func onTap(_ action: @escaping () -> Void) {
        tapAction = action
    }

    @objc private func handleTap() {
        tapAction?()
    }

    override var isHighlighted: Bool {
        didSet { alpha = isEnabled ? (isHighlighted ? 0.65 : 1) : 0.45 }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.45 }
    }
}

final class SecretValueRow: UIView {
    private let valueLabel = UILabel()
    private let copyButton = ActionButton(title: "复制", style: .tonal, accent: Theme.header, height: 36)
    private let placeholder: String
    private(set) var value: String = ""

    init(title: String, placeholder: String) {
        self.placeholder = placeholder
        super.init(frame: .zero)
        backgroundColor = Theme.fieldBackground
        layer.cornerRadius = Theme.controlRadius

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = Theme.mutedInk

        valueLabel.text = placeholder
        valueLabel.font = Theme.monoFont(22, weight: .semibold)
        valueLabel.textColor = Theme.mutedInk
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6

        copyButton.isEnabled = false
        copyButton.tapTarget(self, action: #selector(copyTapped))
        NSLayoutConstraint.activate([
            copyButton.widthAnchor.constraint(equalToConstant: 62)
        ])

        let valueRow = UIStackView.horizontal(spacing: 10)
        valueRow.addArrangedSubview(valueLabel)
        valueRow.addArrangedSubview(copyButton)

        let stack = UIStackView.vertical(spacing: 8)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueRow)
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 12))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: String) {
        self.value = value
        let empty = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        valueLabel.text = empty ? placeholder : value
        valueLabel.textColor = empty ? Theme.mutedInk : Theme.ink
        copyButton.isEnabled = !empty
    }

    @objc private func copyTapped() {
        guard !value.isEmpty else { return }
        UIPasteboard.general.string = value
        HUD.toast("已复制")
    }
}

struct LockTempPasswordInfo {
    let name: String
    let code: Int
    let sn: Int
    let effectiveTime: Int64
    let invalidTime: Int64
    let phase: Int
    let effective: Bool

    init(_ dict: [String: Any]) {
        let name = dict.string("name")
        self.name = name.isEmpty ? "临时密码" : name
        self.code = dict.int("code") ?? 0
        self.sn = dict.int("sn") ?? 0
        self.effectiveTime = dict.int64("effectiveTime") ?? 0
        self.invalidTime = dict.int64("invalidTime") ?? 0
        self.phase = dict.int("phase") ?? 0
        self.effective = dict.bool("effective")
    }

    var validityText: String {
        let start = effectiveTime > 0
            ? DateFormatter.lockDateTime.string(from: Date(timeIntervalSince1970: TimeInterval(effectiveTime)))
            : "-"
        let end = invalidTime > 0
            ? DateFormatter.lockDateTime.string(from: Date(timeIntervalSince1970: TimeInterval(invalidTime)))
            : "长期"
        return "\(start) → \(end)"
    }

    var phaseText: String {
        effective ? "生效中" : "未生效"
    }

    var metaText: String {
        var parts: [String] = []
        if code > 0 { parts.append("编号 \(code)") }
        if sn > 0 { parts.append("SN \(sn)") }
        parts.append(validityText)
        return parts.joined(separator: " · ")
    }
}

final class TempPasswordRowView: UIView {
    var onDelete: (() -> Void)?

    init(password: LockTempPasswordInfo) {
        super.init(frame: .zero)
        backgroundColor = Theme.fieldBackground
        layer.cornerRadius = Theme.controlRadius

        let nameLabel = UILabel()
        nameLabel.text = password.name
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = Theme.ink
        nameLabel.numberOfLines = 1

        let phaseColor = password.effective ? Theme.online : Theme.mutedInk
        let phasePill = PillLabel(text: password.phaseText,
                                  color: phaseColor,
                                  background: phaseColor.withAlphaComponent(0.1))

        let delete = UIButton(type: .system)
        delete.setTitle("删除", for: .normal)
        delete.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        delete.setTitleColor(Theme.offline, for: .normal)
        delete.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let header = UIStackView.horizontal(spacing: 8)
        header.addArrangedSubview(nameLabel)
        header.addArrangedSubview(phasePill)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(delete)

        let meta = UILabel()
        meta.text = password.metaText
        meta.font = .systemFont(ofSize: 11)
        meta.textColor = Theme.mutedInk
        meta.numberOfLines = 2

        let stack = UIStackView.vertical(spacing: 6)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(meta)
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 10))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func deleteTapped() {
        onDelete?()
    }
}

class LockPanelBaseViewController: ScrollStackViewController {
    let device: DeviceInfo
    let accentColor: UIColor
    let baseService: LockBaseService
    let headerView: LockPanelHeaderView
    private var remotePromptVisible = false

    override var supportsRefresh: Bool { true }

    init(device: DeviceInfo) {
        self.device = device
        self.accentColor = Theme.accent(for: device.kind)
        self.baseService = LockBaseService(devId: device.devId)
        self.headerView = LockPanelHeaderView(device: device)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = device.name
        contentStack.addArrangedSubview(headerView)
        addDeviceInfoCard()

        baseService.onOnlineChanged = { [weak self] online in
            self?.headerView.updateOnline(online)
            self?.onlineDidChange(online)
        }
        baseService.onRemoteUnlockRequest = { [weak self] seconds in
            self?.handleRemoteUnlockRequest(seconds: seconds)
        }
    }

    override func handleRefresh() {
        headerView.updateOnline(baseService.isOnline)
        refreshData()
        endRefreshing()
    }

    func addDeviceInfoCard() {
        let card = addCard(14)
        card.spacing = 9
        card.addArrangedSubview(InfoRow(key: "设备类型", value: device.kind.title))
        card.addArrangedSubview(InfoRow(key: "devId", value: device.devId))
        card.addArrangedSubview(InfoRow(key: "categoryCode", value: device.categoryCode.isEmpty ? "-" : device.categoryCode))
        card.addArrangedSubview(InfoRow(key: "productId", value: device.productId.isEmpty ? "-" : device.productId))
        card.addArrangedSubview(InfoRow(key: "在线状态", value: device.isOnline ? "在线" : "离线"))
    }

    func refreshData() {}

    func onlineDidChange(_ online: Bool) {}

    func handleRemoteUnlockRequest(seconds: Int) {
        presentRemoteUnlockPrompt(
            title: "远程开锁请求",
            message: "门锁端正在请求远程开锁（剩余 \(seconds) 秒），是否允许？"
        ) { [weak self] allow in
            self?.replyRemoteUnlock(allow: allow)
        }
    }

    func replyRemoteUnlock(allow: Bool) {
        HUD.showLoading(allow ? "正在允许开锁…" : "正在拒绝请求…")
        baseService.replyRemoteUnlock(allow, success: { [weak self] in
            HUD.hide()
            self?.toast(allow ? "已允许远程开锁" : "已拒绝远程开锁")
        }, failure: { [weak self] message in
            HUD.hide()
            self?.showError(message)
        })
    }

    func presentRemoteUnlockPrompt(title: String, message: String, handler: @escaping (Bool) -> Void) {
        guard !remotePromptVisible, presentedViewController == nil, view.window != nil else { return }
        remotePromptVisible = true
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "拒绝", style: .cancel) { [weak self] _ in
            self?.remotePromptVisible = false
            handler(false)
        })
        alert.addAction(UIAlertAction(title: "允许开锁", style: .default) { [weak self] _ in
            self?.remotePromptVisible = false
            handler(true)
        })
        present(alert, animated: true)
    }

    func pushTempPasswords() {
        if device.kind == .video || device.kind == .photo {
            navigationController?.pushViewController(VideoTempPasswordViewController(device: device), animated: true)
        } else {
            navigationController?.pushViewController(TempPasswordViewController(device: device), animated: true)
        }
    }

    func pushMembers(kind: LockMemberKind) {
        navigationController?.pushViewController(
            MemberListViewController(device: device, kind: kind),
            animated: true
        )
    }

}
