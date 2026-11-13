import UIKit

final class UnlockRecordsViewController: ScrollStackViewController {
    private let device: DeviceInfo
    private lazy var baseService = LockBaseService(devId: device.devId)
    private let listStack = UIStackView.vertical(spacing: 10)
    private let summaryLabel = UILabel()
    private var records: [RecordInfo] = []
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
        title = "开锁记录"
        buildHeader()
        loadRecords()
    }

    override func handleRefresh() {
        loadRecords()
        endRefreshing()
    }

    private func buildHeader() {
        let banner = HeaderBanner(
            badge: "UNLOCK LOGS",
            title: device.name,
            subtitle: "最近的开门记录，最多展示 50 条。",
            accent: Theme.videoAccent
        )
        contentStack.addArrangedSubview(banner)

        addSectionTitle("记录", actionTitle: "刷新", action: { [weak self] in
            self?.loadRecords()
        })

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        summaryLabel.textColor = Theme.secondaryInk
        summaryLabel.numberOfLines = 0
        summaryLabel.text = "正在加载开锁记录…"

        let card = addCard(16)
        card.addArrangedSubview(summaryLabel)
        card.addArrangedSubview(listStack)
    }

    private func loadRecords() {
        guard !isLoading else { return }
        isLoading = true
        summaryLabel.text = "正在加载开锁记录…"
        baseService.fetchUnlockRecords(withOffset: 0, limit: 50, success: { [weak self] items in
            guard let self = self else { return }
            self.isLoading = false
            self.records = items.map { RecordInfo($0) }.filter { $0.time > 0 }
            self.renderRecords()
        }, failure: { [weak self] message in
            guard let self = self else { return }
            self.isLoading = false
            self.records = []
            self.summaryLabel.text = "加载失败：\(message)"
            self.listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        })
    }

    private func renderRecords() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryLabel.text = records.isEmpty ? "暂无开锁记录" : "共 \(records.count) 条开锁记录"
        guard !records.isEmpty else {
            listStack.addArrangedSubview(
                EmptyStateView(title: "暂无开锁记录",
                               message: "门锁产生开锁事件后会显示在这里。",
                               symbol: "list.bullet.rectangle")
            )
            return
        }

        for (index, record) in records.enumerated() {
            if index > 0 {
                listStack.addArrangedSubview(separator())
            }
            listStack.addArrangedSubview(RecordRowView(record: record))
        }
    }
}

final class RecordRowView: UIView {
    init(record: RecordInfo) {
        super.init(frame: .zero)

        let iconBackground = UIView()
        iconBackground.backgroundColor = Theme.videoAccent.withAlphaComponent(0.1)
        iconBackground.layer.cornerRadius = 18
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 36),
            iconBackground.heightAnchor.constraint(equalToConstant: 36)
        ])
        let icon = UIImageView(image: UIImage(systemName: "lock.open"))
        icon.tintColor = Theme.videoAccent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 17),
            icon.heightAnchor.constraint(equalToConstant: 17)
        ])

        let name = UILabel()
        name.text = record.userName
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.textColor = Theme.ink

        let status = PillLabel(text: record.statusText,
                               color: Theme.online,
                               background: Theme.online.withAlphaComponent(0.1))

        let titleRow = UIStackView.horizontal(spacing: 8)
        titleRow.addArrangedSubview(name)
        titleRow.addArrangedSubview(status)
        titleRow.addArrangedSubview(UIView())

        let time = UILabel()
        time.text = record.timeText
        time.font = .systemFont(ofSize: 11)
        time.textColor = Theme.mutedInk

        let idLabel = UILabel()
        idLabel.text = record.userId.isEmpty ? "" : "userId: \(record.userId)"
        idLabel.font = .systemFont(ofSize: 10)
        idLabel.textColor = Theme.mutedInk

        let textStack = UIStackView.vertical(spacing: 3)
        textStack.addArrangedSubview(titleRow)
        textStack.addArrangedSubview(time)
        textStack.addArrangedSubview(idLabel)

        let row = UIStackView.horizontal(spacing: 11, alignment: .center)
        row.addArrangedSubview(iconBackground)
        row.addArrangedSubview(textStack)
        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 10, left: 2, bottom: 10, right: 2))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
