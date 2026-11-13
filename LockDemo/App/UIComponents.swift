import UIKit

final class CardView: UIView {
    init(padding: CGFloat = 16) {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.cardRadius
        layer.masksToBounds = true
        if padding > 0 {
            let spacer = UIView()
            addSubview(spacer)
            spacer.pinEdges(to: self, insets: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func contentView() -> UIView {
        subviews.first ?? self
    }
}

enum ActionStyle {
    case primary
    case tonal
    case outline
    case danger

    func backgroundColor(accent: UIColor) -> UIColor {
        switch self {
        case .primary: return accent
        case .tonal: return accent.withAlphaComponent(0.12)
        case .outline: return .clear
        case .danger: return Theme.offline
        }
    }

    func titleColor(accent: UIColor) -> UIColor {
        switch self {
        case .primary, .danger: return .white
        case .tonal, .outline: return accent
        }
    }
}

final class ActionButton: UIButton {
    private let style: ActionStyle
    private let accent: UIColor
    private let normalHeight: CGFloat

    init(title: String, style: ActionStyle = .primary, accent: UIColor = Theme.header, height: CGFloat = 48) {
        self.style = style
        self.accent = accent
        self.normalHeight = height
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel?.numberOfLines = 1
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.75
        layer.cornerRadius = Theme.controlRadius
        layer.masksToBounds = true
        applyStyle()
        heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.45 }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isEnabled ? (isHighlighted ? 0.72 : 1) : 0.45 }
    }

    private func applyStyle() {
        backgroundColor = style.backgroundColor(accent: accent)
        setTitleColor(style.titleColor(accent: accent), for: .normal)
        if style == .outline {
            layer.borderWidth = 1
            layer.borderColor = accent.withAlphaComponent(0.5).cgColor
        } else {
            layer.borderWidth = 0
        }
    }

    func updateTitle(_ title: String) {
        setTitle(title, for: .normal)
    }
}

final class SectionHeaderLabel: UILabel {
    init(_ text: String) {
        super.init(frame: .zero)
        self.text = text
        font = Theme.sectionFont()
        textColor = Theme.ink
        numberOfLines = 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FormField: UIView {
    let field = UITextField()
    private let titleLabel = UILabel()
    private let container = UIView()

    var text: String {
        get { field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        set { field.text = newValue }
    }

    init(title: String?,
         placeholder: String,
         keyboardType: UIKeyboardType = .default,
         secure: Bool = false,
         capitalization: UITextAutocapitalizationType = .none) {
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = Theme.secondaryInk
        titleLabel.isHidden = (title == nil)

        container.backgroundColor = Theme.fieldBackground
        container.layer.cornerRadius = Theme.controlRadius
        container.layer.borderWidth = 1
        container.layer.borderColor = Theme.hairline.cgColor

        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 16)
        field.textColor = Theme.ink
        field.keyboardType = keyboardType
        field.isSecureTextEntry = secure
        field.autocapitalizationType = capitalization
        field.autocorrectionType = .no
        field.clearButtonMode = .whileEditing
        field.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            field.topAnchor.constraint(equalTo: container.topAnchor),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 48)
        ])

        let stack = UIStackView.vertical(spacing: 7)
        if title != nil {
            stack.addArrangedSubview(titleLabel)
        }
        stack.addArrangedSubview(container)
        addSubview(stack)
        stack.pinEdges(to: self)

        if secure {
            let toggle = UIButton(type: .system)
            toggle.setTitle("显示", for: .normal)
            toggle.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            toggle.setTitleColor(Theme.secondaryInk, for: .normal)
            toggle.addTarget(self, action: #selector(toggleSecure), for: .touchUpInside)
            toggle.frame = CGRect(x: 0, y: 0, width: 46, height: 48)
            field.rightView = toggle
            field.rightViewMode = .always
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleSecure(_ sender: UIButton) {
        field.isSecureTextEntry.toggle()
        sender.setTitle(field.isSecureTextEntry ? "显示" : "隐藏", for: .normal)
        if let text = field.text {
            field.text = nil
            field.text = text
        }
    }
}

final class PillLabel: UILabel {
    var textInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

    init(text: String? = nil, color: UIColor, background: UIColor) {
        super.init(frame: .zero)
        self.text = text
        font = .systemFont(ofSize: 11, weight: .bold)
        textColor = color
        backgroundColor = background
        layer.cornerRadius = 9
        layer.masksToBounds = true
        textAlignment = .center
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = super.sizeThatFits(CGSize(width: size.width - textInsets.left - textInsets.right, height: size.height))
        return CGSize(width: fitted.width + textInsets.left + textInsets.right,
                      height: fitted.height + textInsets.top + textInsets.bottom)
    }
}

final class InfoRow: UIView {
    init(key: String, value: String) {
        super.init(frame: .zero)
        let keyLabel = UILabel()
        keyLabel.text = key
        keyLabel.font = .systemFont(ofSize: 13)
        keyLabel.textColor = Theme.mutedInk
        keyLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = Theme.secondaryInk
        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .right

        let stack = UIStackView.horizontal(spacing: 12, alignment: .top)
        stack.addArrangedSubview(keyLabel)
        stack.addArrangedSubview(valueLabel)
        addSubview(stack)
        stack.pinEdges(to: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class MenuCardButton: UIControl {
    private let iconView = UIImageView()
    private let iconBackground = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(title: String, subtitle: String, symbol: String, accent: UIColor) {
        super.init(frame: .zero)
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.cardRadius
        layer.masksToBounds = true

        iconBackground.backgroundColor = accent.withAlphaComponent(0.12)
        iconBackground.layer.cornerRadius = 12
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(iconView)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = Theme.ink

        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = Theme.mutedInk
        subtitleLabel.numberOfLines = 2

        let textStack = UIStackView.vertical(spacing: 3)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Theme.mutedInk.withAlphaComponent(0.6)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 9).isActive = true

        let stack = UIStackView.horizontal(spacing: 12)
        stack.addArrangedSubview(iconBackground)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(chevron)
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))

        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 42),
            iconBackground.heightAnchor.constraint(equalToConstant: 42),
            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 21),
            iconView.heightAnchor.constraint(equalToConstant: 21)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.65 : 1 }
    }
}

final class EmptyStateView: UIView {
    init(title: String, message: String? = nil, symbol: String = "tray") {
        super.init(frame: .zero)
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = Theme.mutedInk.withAlphaComponent(0.5)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = Theme.secondaryInk
        label.numberOfLines = 0
        label.textAlignment = .center

        let stack = UIStackView.vertical(spacing: 8)
        stack.alignment = .center
        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(label)

        if let message = message, !message.isEmpty {
            let sub = UILabel()
            sub.text = message
            sub.font = .systemFont(ofSize: 12)
            sub.textColor = Theme.mutedInk
            sub.numberOfLines = 0
            sub.textAlignment = .center
            stack.addArrangedSubview(sub)
        }

        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class HeaderBanner: UIView {
    private let badgeLabel = PillLabel(text: nil, color: .white, background: UIColor.white.withAlphaComponent(0.14))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(badge: String, title: String, subtitle: String, accent: UIColor) {
        super.init(frame: .zero)
        backgroundColor = Theme.header
        layer.cornerRadius = 22
        layer.masksToBounds = true

        badgeLabel.text = badge
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        subtitleLabel.numberOfLines = 0

        let accentBar = UIView()
        accentBar.backgroundColor = accent
        accentBar.layer.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.widthAnchor.constraint(equalToConstant: 4).isActive = true

        let badgeRow = UIStackView.horizontal(spacing: 10)
        badgeRow.addArrangedSubview(badgeLabel)
        badgeRow.addArrangedSubview(UIView())

        let textStack = UIStackView.vertical(spacing: 8)
        textStack.addArrangedSubview(badgeRow)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        let row = UIStackView.horizontal(spacing: 14, alignment: .fill)
        row.addArrangedSubview(accentBar)
        row.addArrangedSubview(textStack)

        addSubview(row)
        row.pinEdges(to: self, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}

class ScrollStackViewController: UIViewController {
    let scrollView = UIScrollView()
    let contentStack = UIStackView.vertical(spacing: 16)
    private let refresh = UIRefreshControl()

    var supportsRefresh: Bool { false }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        scrollView.refreshControl = supportsRefresh ? refresh : nil
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.pageInset),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.pageInset),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -Theme.pageInset * 2)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardFrameChanged(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }

    @objc private func keyboardFrameChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - converted.minY)
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }

    @objc func handleRefresh() {}

    func endRefreshing() {
        refresh.endRefreshing()
    }

    func addCard(_ padding: CGFloat = 16) -> UIStackView {
        let card = CardView(padding: padding)
        let stack = UIStackView.vertical(spacing: 12)
        card.contentView().addSubview(stack)
        stack.pinEdges(to: card.contentView())
        contentStack.addArrangedSubview(card)
        return stack
    }

    @discardableResult
    func addSectionTitle(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> UIView {
        let label = SectionHeaderLabel(title)
        guard let actionTitle = actionTitle, let action = action else {
            contentStack.addArrangedSubview(label)
            return label
        }
        let button = ClosureButton(title: actionTitle, closure: action)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.setTitleColor(Theme.secondaryInk, for: .normal)
        let row = UIStackView.horizontal(spacing: 8)
        row.addArrangedSubview(label)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(button)
        contentStack.addArrangedSubview(row)
        return row
    }

    func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = Theme.hairline
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    func addTileGrid(_ tiles: [LockActionTile]) {
        var index = 0
        while index < tiles.count {
            let row = UIStackView.horizontal(spacing: 10, alignment: .fill)
            row.distribution = .fillEqually
            row.addArrangedSubview(tiles[index])
            if index + 1 < tiles.count {
                row.addArrangedSubview(tiles[index + 1])
            } else {
                let placeholder = UIView()
                placeholder.isUserInteractionEnabled = false
                row.addArrangedSubview(placeholder)
            }
            contentStack.addArrangedSubview(row)
            index += 2
        }
    }
}

final class ClosureButton: UIButton {
    private let closure: () -> Void

    init(title: String, closure: @escaping () -> Void) {
        self.closure = closure
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        addTarget(self, action: #selector(invoke), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func invoke() {
        closure()
    }
}

extension UIControl {
    func tapTarget(_ target: Any?, action: Selector) {
        addTarget(target, action: action, for: .touchUpInside)
    }
}
