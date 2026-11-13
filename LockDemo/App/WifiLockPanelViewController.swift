import UIKit

final class WifiLockPanelViewController: LockPanelBaseViewController {
    private let dynamicRow = SecretValueRow(title: "当前动态密码", placeholder: "点击下方按钮获取")
    private let memberCountLabel = UILabel()
    private let memberDetailLabel = UILabel()
    private var dynamicButton: ActionButton?
    private var membersLoading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        buildQuickActions()
        buildDynamicPasswordCard()
        buildMemberCard()
        buildRemoteHintCard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMembers()
    }

    override func refreshData() {
        headerView.updateOnline(baseService.isOnline)
        loadMembers()
    }

    override func onlineDidChange(_ online: Bool) {
        toast(online ? "门锁已上线" : "门锁已离线")
    }

    // MARK: - UI

    private func buildQuickActions() {
        addSectionTitle("快捷操作")

        let dynamic = LockActionTile(title: "动态密码",
                                     subtitle: "实时获取门锁动态密码",
                                     symbol: "number.square",
                                     accent: accentColor)
        dynamic.onTap { [weak self] in
            self?.fetchDynamicPassword()
        }

        let temp = LockActionTile(title: "临时密码",
                                  subtitle: "创建 7 位、24 小时临时密码",
                                  symbol: "clock.badge.checkmark",
                                  accent: accentColor)
        temp.onTap { [weak self] in
            self?.pushTempPasswords()
        }

        let members = LockActionTile(title: "成员管理",
                                     subtitle: "成员与密码 SN 绑定",
                                     symbol: "person.2",
                                     accent: accentColor)
        members.onTap { [weak self] in
            self?.pushMembers(kind: .wifi)
        }

        let refresh = LockActionTile(title: "刷新状态",
                                     subtitle: "同步在线与成员信息",
                                     symbol: "arrow.clockwise",
                                     accent: Theme.header)
        refresh.onTap { [weak self] in
            guard let self = self else { return }
            self.headerView.updateOnline(self.baseService.isOnline)
            self.toast(self.baseService.isOnline ? "门锁在线" : "门锁离线")
            self.loadMembers()
        }

        addTileGrid([dynamic, temp, members, refresh])
    }

    private func buildDynamicPasswordCard() {
        addSectionTitle("动态密码")
        let card = addCard(16)
        card.addArrangedSubview(dynamicRow)

        let button = ActionButton(title: "获取动态密码", accent: accentColor)
        button.tapTarget(self, action: #selector(fetchDynamicPassword))
        card.addArrangedSubview(button)
        dynamicButton = button

        let hint = UILabel()
        hint.text = "动态密码由门锁实时生成，可用于临时开门，请勿长期保存或转发。"
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = Theme.mutedInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)
    }

    private func buildMemberCard() {
        addSectionTitle("成员")

        memberCountLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        memberCountLabel.textColor = Theme.ink
        memberCountLabel.text = "正在加载成员…"

        memberDetailLabel.font = .systemFont(ofSize: 12)
        memberDetailLabel.textColor = Theme.mutedInk
        memberDetailLabel.numberOfLines = 0
        memberDetailLabel.text = "Wi-Fi 门锁通过密码编号（SN）为成员绑定开锁方式。"

        let card = addCard(16)
        card.addArrangedSubview(memberCountLabel)
        card.addArrangedSubview(memberDetailLabel)

        let row = UIStackView.horizontal(spacing: 10)
        let refresh = ActionButton(title: "刷新成员", style: .outline, accent: Theme.header, height: 44)
        refresh.tapTarget(self, action: #selector(refreshMembersTapped))
        let manage = ActionButton(title: "管理成员", style: .tonal, accent: accentColor, height: 44)
        manage.tapTarget(self, action: #selector(manageMembersTapped))
        row.addArrangedSubview(refresh)
        row.addArrangedSubview(manage)
        card.addArrangedSubview(row)
    }

    private func buildRemoteHintCard() {
        addSectionTitle("远程开锁")
        let card = addCard(14)
        let hint = UILabel()
        hint.text = "门锁端发起远程开锁请求时，App 会弹出确认框。可允许或拒绝本次开锁。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.secondaryInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)
    }

    // MARK: - Data

    private func loadMembers() {
        guard !membersLoading else { return }
        membersLoading = true
        baseService.fetchMembers(success: { [weak self] items in
            guard let self = self else { return }
            self.membersLoading = false
            let members = items.compactMap { MemberInfo($0) }
            self.memberCountLabel.text = "共 \(members.count) 位成员"
            let withUnlock = members.filter { !$0.unlockSummary.isEmpty }.count
            self.memberDetailLabel.text = withUnlock > 0
                ? "已有 \(withUnlock) 位成员绑定开锁方式，点击「管理成员」查看详情。"
                : "Wi-Fi 门锁通过密码编号（SN）为成员绑定开锁方式。"
        }, failure: { [weak self] message in
            guard let self = self else { return }
            self.membersLoading = false
            self.memberCountLabel.text = "成员加载失败"
            self.memberDetailLabel.text = message
        })
    }

    // MARK: - Actions

    @objc private func fetchDynamicPassword() {
        dynamicButton?.isEnabled = false
        HUD.showLoading("正在获取动态密码…")
        baseService.fetchDynamicPassword(success: { [weak self] password in
            HUD.hide()
            self?.dynamicButton?.isEnabled = true
            guard let self = self else { return }
            if password.isEmpty {
                self.toast("未获取到动态密码")
            } else {
                self.dynamicRow.setValue(password)
                UIPasteboard.general.string = password
                self.toast("动态密码已获取并复制")
            }
        }, failure: { [weak self] message in
            HUD.hide()
            self?.dynamicButton?.isEnabled = true
            self?.showError(message)
        })
    }

    @objc private func refreshMembersTapped() {
        HUD.showLoading("正在刷新成员…")
        baseService.fetchMembers(success: { [weak self] items in
            HUD.hide()
            guard let self = self else { return }
            let members = items.compactMap { MemberInfo($0) }
            self.memberCountLabel.text = "共 \(members.count) 位成员"
            self.toast("成员已刷新")
        }, failure: { [weak self] message in
            HUD.hide()
            self?.showError(message)
        })
    }

    @objc private func manageMembersTapped() {
        pushMembers(kind: .wifi)
    }
}
