import UIKit

final class VideoLockPanelViewController: LockPanelBaseViewController {
    private lazy var videoService = LockVideoService(devId: device.devId)

    override func viewDidLoad() {
        super.viewDidLoad()
        bindVideoCallbacks()
        buildQuickActions()
        buildRemoteCard()
        buildDeviceHint()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        headerView.updateOnline(baseService.isOnline)
    }

    override func refreshData() {
        headerView.updateOnline(baseService.isOnline)
    }

    override func onlineDidChange(_ online: Bool) {
        toast(online ? "门锁已上线" : "门锁已离线")
    }

    private func bindVideoCallbacks() {
        videoService.onRemoteUnlockRequest = { [weak self] seconds in
            guard let self = self else { return }
            self.presentRemoteUnlockPrompt(
                title: "门锁呼叫请求",
                message: "门锁端发起远程开锁请求（剩余 \(seconds) 秒），是否允许？"
            ) { allow in
                self.replyVideoRemote(allow: allow)
            }
        }
        videoService.onAlarmRequest = { [weak self] seconds in
            self?.toast("门锁触发报警请求（\(seconds) 秒）")
        }
        videoService.onForceLockReport = { [weak self] in
            self?.toast("门锁已上报强制上锁")
        }
        videoService.onOperationMessage = { [weak self] message in
            self?.toast(message)
        }
    }

    private func buildQuickActions() {
        addSectionTitle("设备功能")

        let preview = LockActionTile(title: "实时预览",
                                     subtitle: "P2P 视频与双向对讲",
                                     symbol: "video.fill",
                                     accent: accentColor)
        preview.onTap { [weak self] in
            guard let self = self else { return }
            self.navigationController?.pushViewController(
                VideoPreviewViewController(device: self.device),
                animated: true
            )
        }

        let remote = LockActionTile(title: "远程开锁",
                                    subtitle: "确认后远程开启门锁",
                                    symbol: "lock.open",
                                    accent: accentColor)
        remote.onTap { [weak self] in
            self?.confirmRemoteUnlock()
        }

        let temp = LockActionTile(title: "临时密码",
                                  subtitle: "7 位数字，24 小时内有效",
                                  symbol: "clock.badge.checkmark",
                                  accent: accentColor)
        temp.onTap { [weak self] in
            self?.pushTempPasswords()
        }

        let members = LockActionTile(title: "成员管理",
                                     subtitle: "面板成员与开锁密码",
                                     symbol: "person.2",
                                     accent: accentColor)
        members.onTap { [weak self] in
            self?.pushMembers(kind: .video)
        }

        let records = LockActionTile(title: "开锁记录",
                                     subtitle: "查看最近开锁事件",
                                     symbol: "list.bullet.rectangle",
                                     accent: Theme.header)
        records.onTap { [weak self] in
            guard let self = self else { return }
            self.navigationController?.pushViewController(
                UnlockRecordsViewController(device: self.device),
                animated: true
            )
        }

        let forceLock = LockActionTile(title: "强制上锁",
                                       subtitle: "下发强制上锁指令",
                                       symbol: "lock.shield",
                                       accent: Theme.header)
        forceLock.onTap { [weak self] in
            self?.confirmForceLock()
        }

        let retake = LockActionTile(title: "重新拍照",
                                    subtitle: "触发门锁重新抓拍",
                                    symbol: "camera.viewfinder",
                                    accent: Theme.header)
        retake.onTap { [weak self] in
            self?.confirmRetake()
        }

        let refresh = LockActionTile(title: "刷新状态",
                                     subtitle: "同步在线状态",
                                     symbol: "arrow.clockwise",
                                     accent: Theme.header)
        refresh.onTap { [weak self] in
            guard let self = self else { return }
            self.headerView.updateOnline(self.baseService.isOnline)
            self.toast(self.baseService.isOnline ? "门锁在线" : "门锁离线")
        }

        addTileGrid([preview, remote, temp, members, records, forceLock, retake, refresh])
    }

    private func buildRemoteCard() {
        addSectionTitle("远程开锁请求")
        let card = addCard(14)
        let hint = UILabel()
        hint.text = "门锁端发起呼叫或远程开锁请求时，App 会弹窗提示，可允许或拒绝本次请求。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = Theme.secondaryInk
        hint.numberOfLines = 0
        card.addArrangedSubview(hint)

        let open = ActionButton(title: "模拟远程开锁请求", style: .outline, accent: accentColor, height: 42)
        open.tapTarget(self, action: #selector(remoteOpenTapped))
        card.addArrangedSubview(open)
    }

    private func buildDeviceHint() {
        let card = addCard(14)
        let label = UILabel()
        label.text = "视频门锁基于门锁基础 API 与音视频能力。实时预览会建立 P2P 连接，对讲需要麦克风权限。"
        label.font = .systemFont(ofSize: 11)
        label.textColor = Theme.mutedInk
        label.numberOfLines = 0
        card.addArrangedSubview(label)
    }

    // MARK: - Remote

    @objc private func remoteOpenTapped() {
        confirmRemoteUnlock()
    }

    private func confirmRemoteUnlock() {
        presentRemoteUnlockPrompt(
            title: "远程开锁",
            message: "确认向「\(device.name)」下发远程开锁指令？"
        ) { [weak self] allow in
            self?.replyVideoRemote(allow: allow)
        }
    }

    private func replyVideoRemote(allow: Bool) {
        HUD.showLoading(allow ? "正在远程开锁…" : "正在拒绝请求…")
        videoService.remoteLockOpen(true, confirm: allow, success: { [weak self] in
            HUD.hide()
            self?.toast(allow ? "远程开锁指令已发送" : "已拒绝远程开锁")
        }, failure: { [weak self] message in
            HUD.hide()
            self?.showError(message)
        })
    }

    private func confirmForceLock() {
        showConfirm(title: "强制上锁",
                    message: "将向门锁下发强制上锁指令，可能影响正在进行的开锁流程。",
                    confirmTitle: "强制上锁",
                    destructive: true) { [weak self] in
            guard let self = self else { return }
            HUD.showLoading("正在下发指令…")
            self.videoService.enforceLock(true, success: { [weak self] in
                HUD.hide()
                self?.toast("强制上锁指令已发送")
            }, failure: { [weak self] message in
                HUD.hide()
                self?.showError(message)
            })
        }
    }

    private func confirmRetake() {
        showConfirm(title: "重新拍照",
                    message: "将触发门锁摄像头重新抓拍当前画面。",
                    confirmTitle: "重新拍照") { [weak self] in
            guard let self = self else { return }
            HUD.showLoading("正在下发指令…")
            self.videoService.reTakePhoto(true, success: { [weak self] in
                HUD.hide()
                self?.toast("重新拍照指令已发送")
            }, failure: { [weak self] message in
                HUD.hide()
                self?.showError(message)
            })
        }
    }
}
