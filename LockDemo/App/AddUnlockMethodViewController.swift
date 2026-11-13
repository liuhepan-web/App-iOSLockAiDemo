import UIKit

final class AddUnlockMethodViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private let kind: LockMemberKind
    private let member: MemberInfo
    private let homeId: Int64
    private lazy var baseService = LockBaseService(devId: device.devId)
    private lazy var bleService = LockBLEService(devId: device.devId, homeId: homeId)
    private lazy var videoService = LockVideoService(devId: device.devId)

    private let nameField = FormField(title: "开锁方式名称", placeholder: "例如：成员密码")
    private let snField = FormField(title: "密码编号（SN）", placeholder: "请输入门锁上已有的密码编号", keyboardType: .numberPad)
    private let passwordField = FormField(title: "开锁密码", placeholder: "4–15 位字母或数字", keyboardType: .asciiCapable)
    private var submitButton: ActionButton?

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
        title = kind == .wifi ? "绑定密码 SN" : "添加开锁方式"
        buildForm()
    }

    private var usesSN: Bool {
        kind == .wifi
    }

    private func buildForm() {
        let banner = HeaderBanner(
            badge: "UNLOCK METHOD",
            title: member.name,
            subtitle: usesSN ? "为成员绑定已有密码编号" : "为成员下发一条开锁密码",
            accent: Theme.accent(for: device.kind)
        )
        contentStack.addArrangedSubview(banner)

        let card = addCard(16)
        card.addArrangedSubview(SectionHeaderLabel("开锁方式"))

        let hint = UILabel()
        hint.text = hintText
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.secondaryInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)

        nameField.text = "password"
        card.addArrangedSubview(nameField)

        if usesSN {
            card.addArrangedSubview(snField)
        } else {
            card.addArrangedSubview(passwordField)
        }

        let submit = ActionButton(title: usesSN ? "绑定密码" : "添加密码",
                                  accent: Theme.accent(for: device.kind))
        submit.tapTarget(self, action: #selector(submitTapped))
        card.addArrangedSubview(submit)
        submitButton = submit
    }

    private var hintText: String {
        switch kind {
        case .wifi:
            return "Wi-Fi 门锁不直接下发密码，而是将门锁上已存在的密码编号（SN）绑定到成员。请先在门锁上创建密码并确认其编号。"
        case .video:
            return "通过视频门锁基础 API 为成员添加 4–15 位密码，需门锁在线。"
        case .ble:
            return "蓝牙门锁需保持蓝牙直连或网关在线，才能为成员下发密码。"
        }
    }

    @objc private func submitTapped() {
        var name = nameField.text
        if name.isEmpty {
            name = "password"
            nameField.text = name
        }

        if usesSN {
            guard let sn = Int(snField.text), sn > 0 else {
                toast("请输入有效的密码编号（SN）")
                return
            }
            submitButton?.isEnabled = false
            HUD.showLoading("正在绑定密码…")
            baseService.addUnlockRelation(withMemberUserId: member.userId, sn: sn, success: { [weak self] in
                HUD.hide()
                self?.finishSuccess()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.submitButton?.isEnabled = true
                self?.showError(message)
            })
            return
        }

        let password = passwordField.text
        guard password.count >= 4, password.count <= 15 else {
            toast("请输入 4–15 位开锁密码")
            return
        }

        submitButton?.isEnabled = false
        HUD.showLoading("正在添加开锁方式…")

        if kind == .video {
            videoService.addPassword(forMember: member.userId,
                                     lockUserId: member.lockUserId,
                                     userType: member.userType,
                                     name: name,
                                     password: password,
                                     success: { [weak self] in
                HUD.hide()
                self?.finishSuccess()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.submitButton?.isEnabled = true
                self?.showError(message)
            })
        } else {
            bleService.addPassword(forMemberUserId: member.userId,
                                   lockUserId: member.lockUserId,
                                   userType: member.userType,
                                   name: name,
                                   password: password,
                                   success: { [weak self] in
                HUD.hide()
                self?.finishSuccess()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.submitButton?.isEnabled = true
                self?.showError(message)
            })
        }
    }

    private func finishSuccess() {
        toast(usesSN ? "密码已绑定到成员" : "开锁方式已添加")
        navigationController?.popViewController(animated: true)
    }
}
