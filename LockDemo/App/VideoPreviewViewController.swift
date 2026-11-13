import UIKit

final class VideoPreviewViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private lazy var service = LockVideoService(devId: device.devId)

    private let videoContainer = UIView()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let placeholderLabel = UILabel()
    private var previewButton: ActionButton?
    private var talkButton: ActionButton?
    private var muteButton: ActionButton?
    private var hasAutoStarted = false
    private var isTalking = false

    init(device: DeviceInfo) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "实时预览"
        buildVideoCard()
        buildControls()
        bindService()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAutoStarted else { return }
        hasAutoStarted = true
        if service.isCameraAvailable {
            startPreview()
        } else {
            setStatus("当前设备不支持视频预览", color: Theme.offline, busy: false)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        service.stopTalk()
        service.stopPreview()
        service.disconnect()
    }

    // MARK: - UI

    private func buildVideoCard() {
        let card = addCard(0)
        card.spacing = 0

        videoContainer.backgroundColor = .black
        videoContainer.layer.cornerRadius = Theme.cardRadius
        videoContainer.layer.masksToBounds = true
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            videoContainer.heightAnchor.constraint(equalToConstant: 232)
        ])

        let videoView = service.videoView
        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.addSubview(videoView)
        videoView.pinEdges(to: videoContainer)

        placeholderLabel.text = "预览未开始"
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        placeholderLabel.font = .systemFont(ofSize: 13)
        placeholderLabel.textAlignment = .center
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: videoContainer.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: videoContainer.centerYAnchor)
        ])

        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: videoContainer.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: videoContainer.centerYAnchor, constant: -22)
        ])

        let title = UILabel()
        title.text = device.name
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.addSubview(title)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor, constant: 12),
            title.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: -10)
        ])

        card.addArrangedSubview(videoContainer)
    }

    private func buildControls() {
        addSectionTitle("预览控制")

        let card = addCard(16)
        let preview = ActionButton(title: "开始预览", accent: Theme.videoAccent)
        preview.tapTarget(self, action: #selector(togglePreview))
        card.addArrangedSubview(preview)
        previewButton = preview

        let row = UIStackView.horizontal(spacing: 10)
        let talk = ActionButton(title: "开始对讲", style: .tonal, accent: Theme.videoAccent, height: 44)
        talk.tapTarget(self, action: #selector(toggleTalk))
        talk.isEnabled = service.isTalkSupported()
        let mute = ActionButton(title: "静音", style: .outline, accent: Theme.header, height: 44)
        mute.tapTarget(self, action: #selector(toggleMute))
        row.addArrangedSubview(talk)
        row.addArrangedSubview(mute)
        card.addArrangedSubview(row)
        talkButton = talk
        muteButton = mute

        let statusRow = UIStackView.horizontal(spacing: 8)
        statusRow.addArrangedSubview(spinner)
        spinner.stopAnimating()
        statusLabel.text = "准备连接视频通道…"
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = Theme.secondaryInk
        statusLabel.numberOfLines = 0
        statusRow.addArrangedSubview(statusLabel)
        card.addArrangedSubview(statusRow)

        let hint = UILabel()
        hint.text = "预览与对讲依赖设备网络和 P2P 通道。离开页面会自动停止预览并断开连接。"
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = Theme.mutedInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)
    }

    private func bindService() {
        service.onPreviewStateChanged = { [weak self] previewing, message in
            guard let self = self else { return }
            self.placeholderLabel.isHidden = previewing
            self.previewButton?.updateTitle(previewing ? "停止预览" : "开始预览")
            if let message = message {
                self.setStatus(message, color: previewing ? Theme.online : Theme.secondaryInk, busy: !previewing)
            } else {
                self.setStatus("预览中", color: Theme.online, busy: false)
            }
            if previewing {
                self.spinner.stopAnimating()
            }
        }
        service.onTalkStateChanged = { [weak self] talking in
            guard let self = self else { return }
            self.isTalking = talking
            self.talkButton?.updateTitle(talking ? "结束对讲" : "开始对讲")
            self.setStatus(talking ? "对讲中" : "对讲已结束",
                           color: talking ? Theme.online : Theme.secondaryInk,
                           busy: false)
        }
        service.onOperationMessage = { [weak self] message in
            self?.setStatus(message, color: Theme.secondaryInk, busy: false)
        }
    }

    private func setStatus(_ text: String, color: UIColor, busy: Bool) {
        statusLabel.text = text
        statusLabel.textColor = color
        if busy {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    // MARK: - Actions

    @objc private func togglePreview() {
        if service.isPreviewOn() {
            service.stopPreview()
            setStatus("正在停止预览…", color: Theme.secondaryInk, busy: true)
        } else {
            startPreview()
        }
    }

    private func startPreview() {
        setStatus("正在连接视频通道…", color: Theme.secondaryInk, busy: true)
        service.connectAndStartPreview()
        previewButton?.updateTitle("停止预览")
    }

    @objc private func toggleTalk() {
        if isTalking || service.isTalking() {
            service.stopTalk()
            return
        }
        guard service.isTalkSupported() else {
            toast("当前设备不支持对讲")
            return
        }
        MicrophonePermission.request { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.toast("对讲需要麦克风权限，请在系统设置中开启")
                return
            }
            self.service.startTalk()
            self.setStatus("正在启动对讲…", color: Theme.secondaryInk, busy: true)
        }
    }

    @objc private func toggleMute() {
        let muted = service.isMuted()
        service.setMuted(!muted)
        muteButton?.updateTitle(muted ? "静音" : "取消静音")
        toast(muted ? "已取消静音" : "已静音")
    }
}
