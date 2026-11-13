import UIKit

final class MemberCreateViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private let kind: LockMemberKind
    private let homeId: Int64
    private lazy var baseService = LockBaseService(devId: device.devId)
    private lazy var bleService = LockBLEService(devId: device.devId, homeId: homeId)

    private let nameField = FormField(title: "成员名称", placeholder: "例如：家人 / 保洁")
    private let countryField = FormField(title: "国家码", placeholder: "86", keyboardType: .numberPad)
    private let accountField = FormField(title: "受邀账号", placeholder: "手机号或邮箱")
    private var submitButton: ActionButton?

    init(device: DeviceInfo, kind: LockMemberKind, homeId: Int64) {
        self.device = device
        self.kind = kind
        self.homeId = homeId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "创建成员"
        buildForm()
    }

    private var requiresInvite: Bool {
        kind == .ble
    }

    private func buildForm() {
        let banner = HeaderBanner(
            badge: "NEW MEMBER",
            title: "创建成员",
            subtitle: hintText,
            accent: Theme.accent(for: device.kind)
        )
        contentStack.addArrangedSubview(banner)

        let card = addCard(16)
        card.addArrangedSubview(SectionHeaderLabel("成员信息"))
        card.addArrangedSubview(nameField)

        if requiresInvite {
            countryField.text = AppConfig.shared.countryCode
            card.addArrangedSubview(countryField)
            card.addArrangedSubview(accountField)

            let hint = UILabel()
            hint.text = "Pro 蓝牙门锁通过家庭邀请添加成员，受邀账号需已注册涂鸦账号。"
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = Theme.mutedInk
            hint.numberOfLines = 0
            card.addArrangedSubview(hint)
        } else if kind == .wifi {
            let hint = UILabel()
            hint.text = "Wi-Fi 门锁创建的成员默认不绑定开锁方式，可在成员详情中通过密码 SN 绑定。"
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = Theme.mutedInk
            hint.numberOfLines = 0
            card.addArrangedSubview(hint)
        } else {
            let hint = UILabel()
            hint.text = "视频门锁成员创建后会出现在面板成员列表中。"
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = Theme.mutedInk
            hint.numberOfLines = 0
            card.addArrangedSubview(hint)
        }

        let submit = ActionButton(title: "创建成员", accent: Theme.accent(for: device.kind))
        submit.tapTarget(self, action: #selector(submitTapped))
        card.addArrangedSubview(submit)
        submitButton = submit
    }

    private var hintText: String {
        switch kind {
        case .wifi: return "Wi-Fi 门锁普通成员"
        case .video: return "视频门锁面板成员"
        case .ble: return "蓝牙门锁 Pro 成员邀请"
        }
    }

    @objc private func submitTapped() {
        let name = nameField.text
        guard !name.isEmpty else {
            toast("请输入成员名称")
            return
        }
        var country = ""
        var account = ""
        if requiresInvite {
            country = countryField.text
            account = accountField.text
            guard !account.isEmpty else {
                toast("请输入受邀账号")
                return
            }
            guard !country.isEmpty, country.digitsOnly else {
                toast("请输入正确的国家码")
                return
            }
            guard homeId > 0 else {
                toast("请先选择家庭")
                return
            }
        }

        submitButton?.isEnabled = false
        HUD.showLoading("正在创建成员…")

        switch kind {
        case .wifi:
            baseService.createMember(withName: name, success: { [weak self] in
                HUD.hide()
                self?.finishSuccess()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.submitButton?.isEnabled = true
                self?.showError(message)
            })
        case .video:
            baseService.createPanelMember(withName: name, success: { [weak self] in
                HUD.hide()
                self?.finishSuccess()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.submitButton?.isEnabled = true
                self?.showError(message)
            })
        case .ble:
            bleService.createProMember(withName: name,
                                       countryCode: country,
                                       account: account,
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
        toast("成员创建成功")
        navigationController?.popViewController(animated: true)
    }
}
