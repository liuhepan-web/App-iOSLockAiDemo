import UIKit

final class MemberDetailViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private let kind: LockMemberKind
    private let member: MemberInfo
    private let homeId: Int64
    private lazy var baseService = LockBaseService(devId: device.devId)
    private lazy var bleService = LockBLEService(devId: device.devId, homeId: homeId)

    private let summaryLabel = UILabel()
    private let stateLabel = UILabel()
    private var addButton: ActionButton?
    private var deleteButton: ActionButton?
    private var isPro = true
    private var isLoading = false

    override var supportsRefresh: Bool { true }

    init(device: DeviceInfo, kind: LockMemberKind, member: MemberInfo, homeId: Int64) {
        self.device = device
        self.kind = kind
        self.member = member
        self.homeId = homeId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "成员详情"
        buildProfile()
        buildUnlockMethods()
        buildActions()
        if kind == .ble {
            detectPro()
        } else {
            updateManageState()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSummary()
    }

    override func handleRefresh() {
        loadSummary()
        endRefreshing()
    }

    private var canManage: Bool {
        kind != .ble || isPro
    }

    // MARK: - UI

    private func buildProfile() {
        let banner = HeaderBanner(
            badge: kind == .wifi ? "MEMBER · WIFI" : (kind == .video ? "MEMBER · VIDEO" : "MEMBER · BLE"),
            title: member.name,
            subtitle: memberMeta,
            accent: Theme.accent(for: device.kind)
        )
        contentStack.addArrangedSubview(banner)

        let card = addCard(14)
        card.spacing = 9
        card.addArrangedSubview(InfoRow(key: "userId", value: member.userId))
        card.addArrangedSubview(InfoRow(key: "lockUserId", value: "\(member.lockUserId)"))
        card.addArrangedSubview(InfoRow(key: "userType", value: "\(member.userType)"))
        if !member.contact.isEmpty {
            card.addArrangedSubview(InfoRow(key: "联系方式", value: member.contact))
        }
    }

    private var memberMeta: String {
        var parts: [String] = []
        if member.isAdmin { parts.append("管理员") }
        if member.userType > 0 { parts.append("userType \(member.userType)") }
        if member.lockUserId > 0 { parts.append("lockUserId \(member.lockUserId)") }
        return parts.isEmpty ? "门锁成员" : parts.joined(separator: " · ")
    }

    private func buildUnlockMethods() {
        addSectionTitle("已绑定的开锁方式")

        stateLabel.font = .systemFont(ofSize: 12)
        stateLabel.textColor = Theme.mutedInk
        stateLabel.numberOfLines = 0
        stateLabel.text = ""

        summaryLabel.font = .systemFont(ofSize: 15, weight: .medium)
        summaryLabel.textColor = Theme.ink
        summaryLabel.numberOfLines = 0
        summaryLabel.text = "正在加载…"

        let card = addCard(16)
        card.addArrangedSubview(stateLabel)
        card.addArrangedSubview(summaryLabel)
    }

    private func buildActions() {
        let card = addCard(16)

        let add = ActionButton(title: addTitle, style: .tonal, accent: Theme.accent(for: device.kind), height: 46)
        add.tapTarget(self, action: #selector(addTapped))
        card.addArrangedSubview(add)
        addButton = add

        let delete = ActionButton(title: "删除成员", style: .outline, accent: Theme.offline, height: 46)
        delete.tapTarget(self, action: #selector(deleteTapped))
        card.addArrangedSubview(delete)
        deleteButton = delete
    }

    private var addTitle: String {
        kind == .wifi ? "绑定密码编号（SN）" : "添加开锁密码"
    }

    private func updateManageState() {
        addButton?.isHidden = !canManage
        deleteButton?.isHidden = !canManage
        if !canManage {
            stateLabel.text = "标准蓝牙门锁仅支持查看当前成员，不能添加开锁方式或删除成员。"
        } else {
            stateLabel.text = ""
        }
    }

    private func detectPro() {
        bleService.detectPro { [weak self] pro in
            guard let self = self else { return }
            self.isPro = pro
            self.updateManageState()
            self.loadSummary()
        }
    }

    // MARK: - Data

    private func loadSummary() {
        guard !isLoading else { return }
        isLoading = true

        switch kind {
        case .wifi:
            baseService.fetchUnlockSummary(withUserId: member.userId, success: { [weak self] summary in
                self?.finishSummary(summary)
            }, failure: { [weak self] message in
                self?.finishSummaryError(message)
            })
        case .video:
            baseService.fetchPanelUnlockSummary(withUserId: member.userId, success: { [weak self] summary in
                self?.finishSummary(summary)
            }, failure: { [weak self] message in
                self?.finishSummaryError(message)
            })
        case .ble:
            guard isPro else {
                isLoading = false
                summaryLabel.text = "标准门锁仅支持查看当前成员"
                return
            }
            bleService.fetchUnlockSummary(withUserId: member.userId, success: { [weak self] summary in
                self?.finishSummary(summary)
            }, failure: { [weak self] message in
                self?.finishSummaryError(message)
            })
        }
    }

    private func finishSummary(_ summary: String) {
        isLoading = false
        summaryLabel.text = summary.isEmpty ? "暂未绑定开锁方式" : summary
    }

    private func finishSummaryError(_ message: String) {
        isLoading = false
        summaryLabel.text = "加载失败：\(message)"
    }

    // MARK: - Actions

    @objc private func addTapped() {
        guard canManage else {
            toast("标准门锁不支持添加开锁方式")
            return
        }
        navigationController?.pushViewController(
            AddUnlockMethodViewController(device: device,
                                          kind: kind,
                                          member: member,
                                          homeId: homeId),
            animated: true
        )
    }

    @objc private func deleteTapped() {
        guard canManage else {
            toast("标准门锁不支持删除成员")
            return
        }
        showConfirm(title: "删除成员",
                    message: "确定删除「\(member.name)」？删除后该成员的开锁权限将失效。",
                    confirmTitle: "删除",
                    destructive: true) { [weak self] in
            self?.performDelete()
        }
    }

    private func performDelete() {
        HUD.showLoading("正在删除成员…")
        switch kind {
        case .wifi:
            baseService.deleteMember(withUserId: member.userId, success: { [weak self] in
                HUD.hide()
                self?.deleteFinished()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.showError(message)
            })
        case .video:
            baseService.deletePanelMember(withUserId: member.userId, success: { [weak self] in
                HUD.hide()
                self?.deleteFinished()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.showError(message)
            })
        case .ble:
            bleService.deleteMember(withUserId: member.userId,
                                    userType: member.userType,
                                    success: { [weak self] in
                HUD.hide()
                self?.deleteFinished()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.showError(message)
            })
        }
    }

    private func deleteFinished() {
        toast("成员已删除")
        navigationController?.popViewController(animated: true)
    }
}
