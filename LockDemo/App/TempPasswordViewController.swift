import UIKit

final class TempPasswordViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private lazy var baseService = LockBaseService(devId: device.devId)

    private let nameField = FormField(title: "密码名称", placeholder: "例如：保洁阿姨")
    private let passwordField = FormField(title: "临时密码", placeholder: "请输入 7 位数字密码", keyboardType: .numberPad)
    private let listStack = UIStackView.vertical(spacing: 8)
    private let summaryLabel = UILabel()
    private var createButton: ActionButton?
    private var passwords: [LockTempPasswordInfo] = []
    private var isLoading = false

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
        buildForm()
        buildList()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPasswords()
    }

    override func handleRefresh() {
        loadPasswords()
        endRefreshing()
    }

    private func buildForm() {
        let card = addCard(16)

        let title = SectionHeaderLabel("创建临时密码")
        card.addArrangedSubview(title)

        let hint = UILabel()
        hint.text = "通过门锁基础 API 创建 7 位数字临时密码，创建后 24 小时内有效。"
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
        validityLabel.text = "有效期：创建后 24 小时"
        validityLabel.font = .systemFont(ofSize: 12, weight: .medium)
        validityLabel.textColor = Theme.secondaryInk
        validityLabel.translatesAutoresizingMaskIntoConstraints = false
        validity.addSubview(validityLabel)
        validityLabel.pinEdges(to: validity, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        card.addArrangedSubview(validity)

        let button = ActionButton(title: "创建临时密码", accent: Theme.accent(for: device.kind))
        button.tapTarget(self, action: #selector(createTapped))
        card.addArrangedSubview(button)
        createButton = button
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

    private func loadPasswords() {
        guard !isLoading else { return }
        isLoading = true
        summaryLabel.text = "正在加载临时密码…"
        baseService.fetchTempPasswords(success: { [weak self] items in
            guard let self = self else { return }
            self.isLoading = false
            self.passwords = items.map { LockTempPasswordInfo($0) }
            self.renderPasswords()
        }, failure: { [weak self] message in
            guard let self = self else { return }
            self.isLoading = false
            self.summaryLabel.text = "加载失败：\(message)"
            self.listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        })
    }

    private func renderPasswords() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryLabel.text = passwords.isEmpty ? "暂无临时密码" : "共 \(passwords.count) 条临时密码"
        guard !passwords.isEmpty else {
            listStack.addArrangedSubview(
                EmptyStateView(title: "暂无临时密码",
                               message: "在上方填写名称与 7 位数字密码后创建。",
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

    @objc private func createTapped() {
        var name = nameField.text
        let password = passwordField.text
        guard password.count == 7, password.digitsOnly else {
            toast("请输入 7 位数字临时密码")
            return
        }
        if name.isEmpty {
            name = "temp"
            nameField.text = name
        }
        let now = Date()
        guard let invalid = Calendar.current.date(byAdding: .hour, value: 24, to: now) else {
            return
        }
        createButton?.isEnabled = false
        HUD.showLoading("正在创建临时密码…")
        baseService.createTempPassword(withName: name,
                                       password: password,
                                       effectiveDate: now,
                                       invalidDate: invalid,
                                       success: { [weak self] in
            HUD.hide()
            guard let self = self else { return }
            self.createButton?.isEnabled = true
            self.passwordField.text = ""
            self.toast("临时密码已创建")
            self.loadPasswords()
        }, failure: { [weak self] message in
            HUD.hide()
            self?.createButton?.isEnabled = true
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
            self.baseService.deleteTempPassword(withCode: password.code, success: { [weak self] in
                HUD.hide()
                self?.toast("临时密码已删除")
                self?.loadPasswords()
            }, failure: { [weak self] message in
                HUD.hide()
                self?.showError(message)
            })
        }
    }
}
