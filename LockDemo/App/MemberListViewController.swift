import UIKit

enum LockMemberKind {
    case wifi
    case video
    case ble

    var title: String {
        switch self {
        case .wifi: return "Wi-Fi 门锁成员"
        case .video: return "视频门锁成员"
        case .ble: return "蓝牙门锁成员"
        }
    }

    var hint: String {
        switch self {
        case .wifi:
            return "Wi-Fi 门锁可直接创建成员，并通过密码编号（SN）为成员绑定开锁方式。"
        case .video:
            return "视频门锁通过面板成员接口创建成员，可为成员添加 4–15 位开锁密码。"
        case .ble:
            return "Pro 门锁可邀请账号并管理成员；标准门锁仅支持查看当前成员。"
        }
    }
}

final class MemberListViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private let kind: LockMemberKind
    private let homeId: Int64
    private lazy var baseService = LockBaseService(devId: device.devId)
    private lazy var bleService = LockBLEService(devId: device.devId, homeId: homeId)

    private let summaryLabel = UILabel()
    private let hintLabel = UILabel()
    private let listStack = UIStackView.vertical(spacing: 10)
    private var createButton: ActionButton?
    private var members: [MemberInfo] = []
    private var isLoading = false
    private var isPro = true

    override var supportsRefresh: Bool { true }

    init(device: DeviceInfo, kind: LockMemberKind, homeId: Int64? = nil) {
        self.device = device
        self.kind = kind
        self.homeId = homeId ?? (device.homeId > 0 ? device.homeId : (AppConfig.shared.selectedHome?.homeId ?? 0))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "成员管理"
        buildHeader()
        buildList()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMembers(showSpinner: members.isEmpty)
    }

    override func handleRefresh() {
        loadMembers(showSpinner: false)
        endRefreshing()
    }

    private var canManage: Bool {
        kind != .ble || isPro
    }

    // MARK: - UI

    private func buildHeader() {
        let banner = HeaderBanner(
            badge: kind == .ble ? "BLE MEMBERS" : "LOCK MEMBERS",
            title: device.name,
            subtitle: kind.hint,
            accent: Theme.accent(for: device.kind)
        )
        contentStack.addArrangedSubview(banner)

        addSectionTitle("成员列表", actionTitle: "刷新", action: { [weak self] in
            self?.loadMembers(showSpinner: true)
        })

        summaryLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        summaryLabel.textColor = Theme.ink
        summaryLabel.text = "正在加载成员…"

        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = Theme.mutedInk
        hintLabel.numberOfLines = 0
        hintLabel.text = kind.hint

        let card = addCard(16)
        card.addArrangedSubview(summaryLabel)
        card.addArrangedSubview(hintLabel)

        let create = ActionButton(title: "创建成员", accent: Theme.accent(for: device.kind))
        create.tapTarget(self, action: #selector(createTapped))
        create.isHidden = true
        card.addArrangedSubview(create)
        createButton = create
    }

    private func buildList() {
        let card = addCard(8)
        card.addArrangedSubview(listStack)
        listStack.addArrangedSubview(
            EmptyStateView(title: "正在加载成员…", symbol: "person.2")
        )
    }

    private func renderMembers() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryLabel.text = canManage
            ? "共 \(members.count) 位成员"
            : "当前成员 \(members.count) 位"
        hintLabel.text = canManage
            ? kind.hint
            : "标准门锁仅支持查看当前成员，不能创建、删除成员或添加开锁方式。"
        createButton?.isHidden = !canManage

        guard !members.isEmpty else {
            listStack.addArrangedSubview(
                EmptyStateView(title: "暂无成员",
                               message: canManage ? "点击上方「创建成员」添加第一位成员。" : nil,
                               symbol: "person.crop.circle.badge.questionmark")
            )
            return
        }

        for (index, member) in members.enumerated() {
            if index > 0 {
                listStack.addArrangedSubview(separator())
            }
            let row = MemberRowView(member: member, kind: kind)
            row.tag = index
            row.addTarget(self, action: #selector(memberTapped(_:)), for: .touchUpInside)
            listStack.addArrangedSubview(row)
        }
    }

    // MARK: - Data

    private func loadMembers(showSpinner: Bool) {
        guard !isLoading else { return }
        isLoading = true
        if showSpinner {
            summaryLabel.text = "正在加载成员…"
        }

        if kind == .ble {
            bleService.fetchMembers(success: { [weak self] items, proDevice in
                guard let self = self else { return }
                self.isLoading = false
                self.isPro = proDevice
                self.members = items.compactMap { MemberInfo($0) }
                self.renderMembers()
            }, failure: { [weak self] message in
                guard let self = self else { return }
                self.isLoading = false
                self.summaryLabel.text = "成员加载失败"
                self.hintLabel.text = message
                self.listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            })
            return
        }

        let onSuccess: ([[String: Any]]) -> Void = { [weak self] items in
            guard let self = self else { return }
            self.isLoading = false
            self.members = items.compactMap { MemberInfo($0) }
            self.renderMembers()
        }
        let onFailure: (String) -> Void = { [weak self] message in
            guard let self = self else { return }
            self.isLoading = false
            self.summaryLabel.text = "成员加载失败"
            self.hintLabel.text = message
            self.listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }
        if kind == .video {
            baseService.fetchPanelMembers(success: onSuccess, failure: onFailure)
        } else {
            baseService.fetchMembers(success: onSuccess, failure: onFailure)
        }
    }

    // MARK: - Actions

    @objc private func memberTapped(_ sender: UIControl) {
        guard sender.tag >= 0, sender.tag < members.count else { return }
        let member = members[sender.tag]
        navigationController?.pushViewController(
            MemberDetailViewController(device: device,
                                       kind: kind,
                                       member: member,
                                       homeId: homeId),
            animated: true
        )
    }

    @objc private func createTapped() {
        guard canManage else {
            toast("标准门锁不支持创建成员")
            return
        }
        navigationController?.pushViewController(
            MemberCreateViewController(device: device, kind: kind, homeId: homeId),
            animated: true
        )
    }
}

final class MemberRowView: UIControl {
    init(member: MemberInfo, kind: LockMemberKind) {
        super.init(frame: .zero)

        let avatar = UILabel()
        avatar.text = String(member.name.prefix(1))
        avatar.font = .systemFont(ofSize: 17, weight: .bold)
        avatar.textColor = .white
        avatar.textAlignment = .center
        avatar.backgroundColor = Theme.accent(for: kind == .ble ? .ble : (kind == .video ? .video : .wifi))
        avatar.layer.cornerRadius = 20
        avatar.layer.masksToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40)
        ])

        let name = UILabel()
        name.text = member.name
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.textColor = Theme.ink

        let meta = UILabel()
        if kind == .wifi {
            meta.text = "userId: \(member.userId) · type \(member.userType)"
        } else {
            meta.text = "userId: \(member.userId) · lockUserId \(member.lockUserId)"
        }
        meta.font = .systemFont(ofSize: 10)
        meta.textColor = Theme.mutedInk
        meta.numberOfLines = 1

        let summary = UILabel()
        summary.text = member.unlockSummary.isEmpty ? "暂未绑定开锁方式" : member.unlockSummary
        summary.font = .systemFont(ofSize: 11)
        summary.textColor = Theme.secondaryInk
        summary.numberOfLines = 2

        let textStack = UIStackView.vertical(spacing: 3)
        textStack.addArrangedSubview(name)
        textStack.addArrangedSubview(meta)
        textStack.addArrangedSubview(summary)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Theme.mutedInk.withAlphaComponent(0.5)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 9).isActive = true

        let row = UIStackView.horizontal(spacing: 11, alignment: .center)
        row.isUserInteractionEnabled = false
        row.addArrangedSubview(avatar)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(chevron)
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 10, left: 2, bottom: 10, right: 4))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}
