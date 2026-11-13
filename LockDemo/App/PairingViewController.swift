import UIKit

enum LockPairingMode: Int, CaseIterable {
    case ez
    case ap
    case qr
    case ble

    var title: String {
        switch self {
        case .ez: return "EZ"
        case .ap: return "AP"
        case .qr: return "二维码"
        case .ble: return "蓝牙"
        }
    }

    var heading: String {
        switch self {
        case .ez: return "EZ 配网"
        case .ap: return "AP 配网"
        case .qr: return "二维码配网"
        case .ble: return "蓝牙配网"
        }
    }

    var intro: String {
        switch self {
        case .ez:
            return "请确保手机已连接 2.4GHz Wi-Fi，设备处于配网闪灯状态。设备会自动接收路由器信息。"
        case .ap:
            return "填写路由器 2.4GHz Wi-Fi 信息后开始。随后在系统 Wi-Fi 设置中连接设备热点（通常为 SmartLife-XXXX），再返回本页完成配网。"
        case .qr:
            return "填写设备要连接的 2.4GHz Wi-Fi 后生成二维码。将二维码正对设备摄像头（约 15–20cm），保持页面打开直至配网成功。"
        case .ble:
            return "扫描附近待配网的蓝牙设备并激活。请开启手机蓝牙，将设备置于配网状态并靠近手机。"
        }
    }

    var objcMode: LockWiFiPairingMode {
        switch self {
        case .ez: return .EZ
        case .ap: return .AP
        case .qr: return .qrCode
        case .ble: return .EZ
        }
    }

    var startTitle: String {
        switch self {
        case .ez: return "开始 EZ 配网"
        case .ap: return "开始 AP 配网"
        case .qr: return "生成二维码并配网"
        case .ble: return "开始扫描"
        }
    }
}

final class PairingViewController: ScrollStackViewController {
    private let home: HomeInfo
    private var mode: LockPairingMode
    private let service = LockPairingService()

    private let ssidField = FormField(title: "Wi-Fi SSID", placeholder: "2.4GHz Wi-Fi 名称")
    private let passwordField = FormField(title: "Wi-Fi 密码", placeholder: "路由器 Wi-Fi 密码", secure: true)
    private let qrImageView = UIImageView()
    private let qrHintLabel = UILabel()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let bleListStack = UIStackView.vertical(spacing: 8)

    private var statusRow: UIStackView?
    private var startButton: ActionButton?
    private var scanButton: ActionButton?
    private var stopButton: ActionButton?

    private var isBusy = false
    private var isScanning = false
    private var bleDevices: [BLEDeviceInfo] = []
    private var completed = false

    init(home: HomeInfo, initialMode: LockPairingMode) {
        self.home = home
        self.mode = initialMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设备配网"
        configurePersistentViews()
        bindService()
        ssidField.text = LockSDKSupport.currentWifiSSID()
        render()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSessions()
    }

    private func configurePersistentViews() {
        spinner.hidesWhenStopped = true
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = Theme.secondaryInk
        statusLabel.numberOfLines = 0

        qrImageView.contentMode = .scaleAspectFit
        qrImageView.backgroundColor = .white
        qrImageView.layer.cornerRadius = 10
        qrImageView.layer.masksToBounds = true
        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.widthAnchor.constraint(equalToConstant: 230).isActive = true
        qrImageView.heightAnchor.constraint(equalToConstant: 230).isActive = true
        qrImageView.isHidden = true

        qrHintLabel.text = "请用设备摄像头扫描二维码，保持页面打开直至配网成功。"
        qrHintLabel.font = .systemFont(ofSize: 12)
        qrHintLabel.textColor = Theme.secondaryInk
        qrHintLabel.numberOfLines = 0
        qrHintLabel.textAlignment = .center
        qrHintLabel.isHidden = true

        bleListStack.spacing = 8
    }

    private func bindService() {
        service.onProgress = { [weak self] message in
            self?.setStatus(message, busy: true)
        }
        service.onSuccess = { [weak self] device in
            self?.handleSuccess(device)
        }
        service.onFailure = { [weak self] message in
            self?.handleFailure(message)
        }
        service.onBLEDeviceFound = { [weak self] dict in
            guard let self = self, let device = BLEDeviceInfo(dict) else { return }
            guard !self.bleDevices.contains(where: { $0.uuid == device.uuid }) else { return }
            self.bleDevices.append(device)
            self.reloadBLEList()
            self.setStatus("已发现 \(self.bleDevices.count) 台设备，点击「开始配网」",
                           color: Theme.secondaryInk,
                           busy: self.isScanning)
        }
    }

    // MARK: - Rendering

    private func render() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        statusRow = nil
        startButton = nil
        scanButton = nil
        stopButton = nil

        let segmented = UISegmentedControl(items: LockPairingMode.allCases.map { $0.title })
        segmented.selectedSegmentIndex = mode.rawValue
        segmented.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        contentStack.addArrangedSubview(segmented)

        switch mode {
        case .ble:
            buildBLE()
        default:
            buildWiFi()
        }

        let note = UILabel()
        note.text = "配网需要设备处于待配网状态。若多次失败，请重启设备或检查 2.4GHz Wi-Fi 密码。"
        note.font = .systemFont(ofSize: 11)
        note.textColor = Theme.mutedInk
        note.numberOfLines = 0
        contentStack.addArrangedSubview(note)
    }

    private func buildWiFi() {
        let card = addCard(16)
        card.addArrangedSubview(SectionHeaderLabel(mode.heading))

        let intro = UILabel()
        intro.text = mode.intro
        intro.font = .systemFont(ofSize: 13)
        intro.textColor = Theme.secondaryInk
        intro.numberOfLines = 0
        card.addArrangedSubview(intro)

        card.addArrangedSubview(ssidField)

        let fillWifi = ActionButton(title: "使用当前 Wi-Fi 名称", style: .outline, accent: Theme.wifiAccent, height: 40)
        fillWifi.tapTarget(self, action: #selector(fillCurrentWifi))
        card.addArrangedSubview(fillWifi)

        card.addArrangedSubview(passwordField)

        if mode == .qr {
            let qrContainer = UIView()
            qrContainer.backgroundColor = Theme.fieldBackground
            qrContainer.layer.cornerRadius = 14
            let qrStack = UIStackView.vertical(spacing: 10)
            qrStack.alignment = .center
            qrStack.addArrangedSubview(qrImageView)
            qrStack.addArrangedSubview(qrHintLabel)
            qrContainer.addSubview(qrStack)
            let insets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            qrStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                qrStack.leadingAnchor.constraint(equalTo: qrContainer.leadingAnchor, constant: insets.left),
                qrStack.trailingAnchor.constraint(equalTo: qrContainer.trailingAnchor, constant: -insets.right),
                qrStack.topAnchor.constraint(equalTo: qrContainer.topAnchor, constant: insets.top),
                qrStack.bottomAnchor.constraint(equalTo: qrContainer.bottomAnchor, constant: -insets.bottom)
            ])
            qrContainer.isHidden = qrImageView.image == nil
            card.addArrangedSubview(qrContainer)
            card.addArrangedSubview(buildStatusRow())
        }

        if mode != .qr {
            card.addArrangedSubview(buildStatusRow())
        }

        let start = ActionButton(title: mode.startTitle, accent: Theme.wifiAccent)
        start.tapTarget(self, action: #selector(startWiFiTapped))
        start.isEnabled = !isBusy
        card.addArrangedSubview(start)
        startButton = start

        if mode == .ap {
            let hint = UILabel()
            hint.text = "提示：开始后如仍未连接设备热点，请前往系统「设置 → 无线局域网」手动连接 SmartLife-XXXX，再返回本页等待结果。"
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = Theme.mutedInk
            hint.numberOfLines = 0
            card.addArrangedSubview(hint)
        }
    }

    private func buildBLE() {
        let card = addCard(16)
        card.addArrangedSubview(SectionHeaderLabel(mode.heading))

        let intro = UILabel()
        intro.text = mode.intro
        intro.font = .systemFont(ofSize: 13)
        intro.textColor = Theme.secondaryInk
        intro.numberOfLines = 0
        card.addArrangedSubview(intro)

        let buttons = UIStackView.horizontal(spacing: 10)
        let scan = ActionButton(title: "开始扫描", accent: Theme.bleAccent, height: 44)
        scan.tapTarget(self, action: #selector(scanTapped))
        let stop = ActionButton(title: "停止扫描", style: .outline, accent: Theme.bleAccent, height: 44)
        stop.tapTarget(self, action: #selector(stopScanTapped))
        buttons.addArrangedSubview(scan)
        buttons.addArrangedSubview(stop)
        card.addArrangedSubview(buttons)
        scanButton = scan
        stopButton = stop

        card.addArrangedSubview(buildStatusRow())
        card.addArrangedSubview(bleListStack)

        updateBLEButtons()
        reloadBLEList()

        let hint = UILabel()
        hint.text = "提示：蓝牙配网依赖蓝牙与定位权限。若列表为空，请确认蓝牙已开启、设备已进入配网模式。"
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = Theme.mutedInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)
    }

    private func buildStatusRow() -> UIStackView {
        let row = UIStackView.horizontal(spacing: 8, alignment: .center)
        row.addArrangedSubview(spinner)
        row.addArrangedSubview(statusLabel)
        row.isHidden = statusLabel.text?.isEmpty ?? true
        statusRow = row
        return row
    }

    private func reloadBLEList() {
        bleListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard mode == .ble else { return }

        if bleDevices.isEmpty {
            bleListStack.addArrangedSubview(
                EmptyStateView(title: "未发现蓝牙设备",
                               message: "点击「开始扫描」，并将设备置于配网状态。",
                               symbol: "dot.radiowaves.left.and.right")
            )
            return
        }

        for (index, device) in bleDevices.enumerated() {
            let row = UIView()
            row.backgroundColor = Theme.fieldBackground
            row.layer.cornerRadius = 12

            let name = UILabel()
            name.text = device.name
            name.font = .systemFont(ofSize: 15, weight: .semibold)
            name.textColor = Theme.ink

            let meta = UILabel()
            var metaParts: [String] = ["uuid: \(device.uuid)"]
            if !device.productId.isEmpty { metaParts.append("productId: \(device.productId)") }
            if !device.mac.isEmpty { metaParts.append("mac: \(device.mac)") }
            meta.text = metaParts.joined(separator: " · ")
            meta.font = .systemFont(ofSize: 10)
            meta.textColor = Theme.mutedInk
            meta.numberOfLines = 2

            let activate = ActionButton(title: "开始配网", style: .tonal, accent: Theme.bleAccent, height: 38)
            activate.tag = index
            activate.tapTarget(self, action: #selector(activateBLETapped(_:)))
            activate.isEnabled = !isBusy
            NSLayoutConstraint.activate([
                activate.widthAnchor.constraint(equalToConstant: 96)
            ])

            let textStack = UIStackView.vertical(spacing: 4)
            textStack.addArrangedSubview(name)
            textStack.addArrangedSubview(meta)

            let rowStack = UIStackView.horizontal(spacing: 10)
            rowStack.addArrangedSubview(textStack)
            rowStack.addArrangedSubview(activate)
            row.addSubview(rowStack)
            rowStack.pinEdges(to: row, insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 10))
            bleListStack.addArrangedSubview(row)
        }
    }

    // MARK: - Status

    private func setStatus(_ text: String, color: UIColor = Theme.secondaryInk, busy: Bool) {
        statusLabel.text = text
        statusLabel.textColor = color
        statusRow?.isHidden = text.isEmpty
        if busy {
            spinner.startAnimating()
            spinner.isHidden = false
        } else {
            spinner.stopAnimating()
            spinner.isHidden = true
        }
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        startButton?.isEnabled = !busy
        updateBLEButtons()
        if let start = startButton {
            start.alpha = busy ? 0.5 : 1
        }
    }

    private func updateBLEButtons() {
        scanButton?.isEnabled = !isBusy && !isScanning
        stopButton?.isEnabled = isScanning && !isBusy
    }

    private func stopSessions() {
        service.stopWifiPairing()
        service.stopBLEScan()
        isScanning = false
        isBusy = false
        spinner.stopAnimating()
    }

    // MARK: - Actions

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        guard let newMode = LockPairingMode(rawValue: sender.selectedSegmentIndex), newMode != mode else { return }
        stopSessions()
        mode = newMode
        statusLabel.text = nil
        completed = false
        render()
    }

    @objc private func fillCurrentWifi() {
        let ssid = LockSDKSupport.currentWifiSSID()
        if ssid.isEmpty {
            toast("无法读取当前 Wi-Fi 名称，请手动填写")
        } else {
            ssidField.text = ssid
            toast("已填入当前 Wi-Fi：\(ssid)")
        }
    }

    @objc private func startWiFiTapped() {
        guard !isBusy else { return }
        let ssid = ssidField.text
        guard !ssid.isEmpty else {
            toast("请输入 Wi-Fi SSID")
            return
        }
        completed = false
        setBusy(true)

        if mode == .qr {
            startQRCodeFlow(ssid: ssid, password: passwordField.text)
        } else {
            setStatus("正在获取配网 Token…", busy: true)
            service.startWifiPairing(with: mode.objcMode,
                                     homeId: home.homeId,
                                     ssid: ssid,
                                     password: passwordField.text,
                                     timeout: 100)
        }
    }

    private func startQRCodeFlow(ssid: String, password: String) {
        setStatus("正在获取配网 Token…", busy: true)
        service.fetchPairingToken(withHomeId: home.homeId, success: { [weak self] token in
            guard let self = self, self.mode == .qr, self.isBusy else { return }
            guard !token.isEmpty else {
                self.handleFailure("获取配网 Token 失败，请重试")
                return
            }
            let payload = self.qrPayload(ssid: ssid, password: password, token: token)
            guard let image = QRCodeRenderer.image(from: payload, size: 480) else {
                self.handleFailure("二维码生成失败，请重试")
                return
            }
            self.qrImageView.image = image
            self.qrImageView.isHidden = false
            self.qrHintLabel.isHidden = false
            if let container = self.qrImageView.superview?.superview {
                container.isHidden = false
            }
            self.setStatus("二维码已生成，等待设备扫码…", color: Theme.videoAccent, busy: true)
            self.service.startQRCodePairing(withToken: token,
                                            ssid: ssid,
                                            password: password,
                                            timeout: 100)
        }, failure: { [weak self] message in
            self?.handleFailure(message)
        })
    }

    private func qrPayload(ssid: String, password: String, token: String) -> String {
        let dict: [String: String] = ["s": ssid, "p": password, "t": token]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "{\"s\":\"\(ssid)\",\"p\":\"\(password)\",\"t\":\"\(token)\"}"
    }

    @objc private func scanTapped() {
        guard !isBusy, !isScanning else { return }
        completed = false
        bleDevices.removeAll()
        reloadBLEList()
        isScanning = true
        updateBLEButtons()
        setStatus("正在扫描附近可配网的蓝牙设备…", busy: true)
        service.startBLEScan()
        if !service.isBluetoothPoweredOn() {
            toast("蓝牙未开启或权限未授予，请在系统设置中允许蓝牙")
        }
    }

    @objc private func stopScanTapped() {
        service.stopBLEScan()
        isScanning = false
        updateBLEButtons()
        setStatus("已停止扫描，共发现 \(bleDevices.count) 台设备", busy: false)
    }

    @objc private func activateBLETapped(_ sender: UIButton) {
        guard sender.tag >= 0, sender.tag < bleDevices.count, !isBusy else { return }
        let device = bleDevices[sender.tag]
        service.stopBLEScan()
        isScanning = false
        completed = false
        setBusy(true)
        updateBLEButtons()
        setStatus("正在激活「\(device.name)」…", color: Theme.bleAccent, busy: true)
        service.activateBLEDevice(withUUID: device.uuid, homeId: home.homeId, success: { [weak self] _ in
            self?.handleSuccess(["name": device.name])
        }, failure: { [weak self] message in
            self?.handleFailure(message)
        })
    }

    // MARK: - Result

    private func handleSuccess(_ device: [String: Any]) {
        guard !completed else { return }
        completed = true
        setBusy(false)
        isScanning = false
        updateBLEButtons()
        let name = device.string("name")
        let title = name.isEmpty ? "配网成功" : "配网成功：\(name)"
        setStatus(title, color: Theme.online, busy: false)

        let alert = UIAlertController(
            title: "配网成功",
            message: "设备已加入「\(home.name)」，返回后可在设备列表中查看。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "查看设备", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func handleFailure(_ message: String) {
        guard !completed else { return }
        setBusy(false)
        setStatus(message, color: Theme.offline, busy: false)
        if view.window != nil {
            showAlert(title: "配网失败", message: message)
        }
    }
}
