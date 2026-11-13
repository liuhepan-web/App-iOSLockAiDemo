import UIKit

/// 视频 / 拍照门锁的在线、离线临时密码（对应 Android VideoLockTempPwdActivity）。
final class VideoTempPasswordViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private lazy var baseService = LockBaseService(devId: device.devId)
    private var isVideo: Bool { device.kind == .video }

    private let snLabel = UILabel()
    private let nameField = FormField(title: "密码名称", placeholder: "留空默认 online / offline")
    private let passwordField = FormField(title: "临时密码", placeholder: "请输入 4-15 位密码")
    private let listStack = UIStackView.vertical(spacing: 8)
    private let summaryLabel = UILabel()
    private var onlineButton: ActionButton?
    private var offlineButton: ActionButton?
    private var passwords: [LockTempPasswordInfo] = []
    private var isLoading = false
    private var hardwareSn = 0
    private var snDpId = 0
    private var snRequested = false

    override var supportsRefresh: Bool { true }

    init(device: DeviceInfo) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "临时密码"
        buildSnCard()
        buildForm()
        buildList()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isVideo && !snRequested {
            loadSn()
        }
        loadPasswords()
    }

    override func handleRefresh() {
        if isVideo {
            loadSn()
        }
        loadPasswords()
        endRefreshing()
    }

    private func buildSnCard() {
        let card = addCard(16)
        card.addArrangedSubview(SectionHeaderLabel("密码编号（SN）"))

        snLabel.font = .systemFont(ofSize: 13)
        snLabel.textColor = Theme.secondaryInk
        snLabel.numberOfLines = 0
        snLabel.text = isVideo ? "正在获取门锁 SN…" : "拍照锁无需 SN，可直接创建在线临时密码。"
        card.addArrangedSubview(snLabel)

        let hint = UILabel()
        hint.text = isVideo
            ? "在线密码必须使用云端分配的硬件 SN；离线密码由云端生成，有效期为 7 天。"
            : "在线密码有效期为 24 小时。离线密码请在下方密码列表中查看。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.mutedInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)
    }

    private func buildForm() {
        let card = addCard(16)
        card.addArrangedSubview(SectionHeaderLabel("创建临时密码"))

        let hint = UILabel()
        hint.text = isVideo
            ? "输入 4-15 位密码。在线密码 24 小时有效，离线密码 7 天有效且可多次使用。"
            : "输入 4-15 位密码，创建后 24 小时内有效。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.secondaryInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)

        card.addArrangedSubview(nameField)
        card.addArrangedSubview(passwordField)

        let validity = UIView()
        validity.backgroundColor = Theme.fieldBackground
        validity.layer.cornerRadius = Theme.controlRadius
        let validityLabel = UILabel()
        validityLabel.text = isVideo ? "有效期：在线 24 小时 · 离线 7 天" : "有效期：创建后 24 小时"
        validityLabel.font = .systemFont(ofSize: 12, weight: .medium)
        validityLabel.textColor = Theme.secondaryInk
        validityLabel.translatesAutoresizingMaskIntoConstraints = false
        validity.addSubview(validityLabel)
        validityLabel.pinEdges(to: validity, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        card.addArrangedSubview(validity)

        let accent = Theme.accent(for: device.kind)
        let online = ActionButton(title: "创建在线密码", accent: accent)
        online.tapTarget(self, action: #selector(createOnlineTapped))
        card.addArrangedSubview(online)
        onlineButton = online

        let offline = ActionButton(title: "创建离线密码", style: .outline, accent: accent)
        offline.tapTarget(self, action: #selector(createOfflineTapped))
        card.addArrangedSubview(offline)
        offlineButton = offline
    }

    private func buildList() {
        addSectionTitle("已创建的临时密码", actionTitle: "刷新", action: { [weak self] in
            self?.loadPasswords()
        })

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        summaryLabel.textColor = Theme.secondaryInk
        summaryLabel.numberOfLines = 0
        summaryLabel.text = "正在加载…"

        let card = addCard(16)
        card.addArrangedSubview(summaryLabel)
        card.addArrangedSubview(listStack)
    }

    private func loadSn() {
        guard isVideo else { return }
        snRequested = true
        snLabel.text = "正在获取门锁 SN…"
        baseService.fetchVideoTempPasswordSn(success: { [weak self] info in
            guard let self = self else { return }
            self.snDpId = (info["dpId"] as? NSNumber)?.intValue ?? 0
            self.hardwareSn = (info["sn"] as? NSNumber)?.intValue ?? 0
            if self.hardwareSn > 0 {
                self.snLabel.text = "SN \(self.hardwareSn) · dpId \(self.snDpId)"
            } else {
                self.snLabel.text = "未获取到门锁 SN，暂时无法创建在线密码，可下拉刷新重试。"
            }
        }, failure: { [weak self] message in
            guard let self = self else { return }
            self.snRequested = false
            self.snLabel.text = "获取 SN 失败：\(message)"
        })
    }

    private func loadPasswords() {
        guard !isLoading else { return }
        isLoading = true
        summaryLabel.text = "正在加载临时密码…"

        let success: ([[String: Any]]) -> Void = { [weak self] items in
            guard let self = self else { return }
            self.isLoading = false
            self.passwords = items.map { LockTempPasswordInfo($0) }
            self.renderPasswords()
        }
        let failure: (String) -> Void = { [weak self] message in
            guard let self = self else { return }
            self.isLoading = false
            self.summaryLabel.text = "加载失败：\(message)"
            self.listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }

        if isVideo {
            baseService.fetchVideoTempPasswords(success: success, failure: failure)
        } else {
            baseService.fetchPhotoTempPasswords(success: success, failure: failure)
        }
    }

    private func renderPasswords() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryLabel.text = passwords.isEmpty ? "暂无临时密码" : "共 \(passwords.count) 条临时密码"
        guard !passwords.isEmpty else {
            listStack.addArrangedSubview(
                EmptyStateView(title: "暂无临时密码",
                               message: isVideo
                                   ? "在上方填写 4-15 位密码后创建在线或离线密码。"
                                   : "在上方填写 4-15 位密码后创建在线密码。",
                               symbol: "key")
            )
            return
        }
        for password in passwords {
            let row = TempPasswordRowView(password: password)
            row.onDelete = { [weak self] in
                self?.confirmDelete(password)
            }
            listStack.addArrangedSubview(row)
        }
    }

    @objc private func createOnlineTapped() {
        let password = passwordField.text
        guard password.count >= 4, password.count <= 15 else {
            toast("请输入 4-15 位临时密码")
            return
        }
        var name = nameField.text
        if name.isEmpty {
            name = "online"
            nameField.text = name
        }
        if isVideo && hardwareSn <= 0 {
            toast("未获取到门锁 SN，无法创建在线密码")
            return
        }
        let now = Date()
        guard let invalid = Calendar.current.date(byAdding: .hour, value: 24, to: now) else {
            return
        }
        onlineButton?.isEnabled = false
        HUD.showLoading("正在创建在线密码…")

        let success: () -> Void = { [weak self] in
            HUD.hide()
            guard let self = self else { return }
            self.onlineButton?.isEnabled = true
            self.passwordField.text = ""
            self.toast("在线临时密码已创建")
            self.loadPasswords()
        }
        let failure: (String) -> Void = { [weak self] message in
            HUD.hide()
            self?.onlineButton?.isEnabled = true
            self?.showError(message)
        }

        if isVideo {
            baseService.createVideoTempPassword(withName: name,
                                                password: password,
                                                sn: hardwareSn,
                                                effectiveDate: now,
                                                invalidDate: invalid,
                                                success: success,
                                                failure: failure)
        } else {
            baseService.createPhotoTempPassword(withName: name,
                                                password: password,
                                                effectiveDate: now,
                                                invalidDate: invalid,
                                                success: success,
                                                failure: failure)
        }
    }

    @objc private func createOfflineTapped() {
        guard isVideo else {
            toast("拍照锁的离线密码请通过在线密码列表管理")
            return
        }
        var name = nameField.text
        if name.isEmpty {
            name = "offline"
            nameField.text = name
        }
        let now = Date()
        guard let invalid = Calendar.current.date(byAdding: .day, value: 7, to: now) else {
            return
        }
        offlineButton?.isEnabled = false
        HUD.showLoading("正在创建离线密码…")
        baseService.createVideoOfflinePassword(withName: name,
                                               effectiveDate: now,
                                               invalidDate: invalid,
                                               success: { [weak self] password in
            HUD.hide()
            guard let self = self else { return }
            self.offlineButton?.isEnabled = true
            self.presentCopiedPassword(title: "离线临时密码已创建",
                                       password: password,
                                       message: "该密码 7 天内有效，可多次使用。")
            self.loadPasswords()
        }, failure: { [weak self] message in
            HUD.hide()
            self?.offlineButton?.isEnabled = true
            self?.showError(message)
        })
    }

    private func confirmDelete(_ password: LockTempPasswordInfo) {
        showConfirm(title: "删除临时密码",
                    message: "确定删除「\(password.name)」？删除后该密码将无法开门。",
                    confirmTitle: "删除",
                    destructive: true) { [weak self] in
            guard let self = self else { return }
            guard password.code > 0 else {
                self.showError("该密码缺少有效编号，无法删除")
                return
            }
            HUD.showLoading("正在删除…")
            let success: () -> Void = { [weak self] in
                HUD.hide()
                self?.toast("临时密码已删除")
                self?.loadPasswords()
            }
            let failure: (String) -> Void = { [weak self] message in
                HUD.hide()
                self?.showError(message)
            }
            if self.isVideo {
                self.baseService.deleteVideoTempPassword(withId: password.code,
                                                         success: success,
                                                         failure: failure)
            } else {
                self.baseService.deletePhotoTempPassword(withId: password.code,
                                                         success: success,
                                                         failure: failure)
            }
        }
    }
}
