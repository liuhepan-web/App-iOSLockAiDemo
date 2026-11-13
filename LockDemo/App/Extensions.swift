import UIKit
import AVFoundation

func onMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}

extension UIView {
    func pinEdges(to other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ])
    }

    func pinEdges(to layoutGuide: UILayoutGuide, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: layoutGuide.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor, constant: -insets.bottom)
        ])
    }

    func setHidden(_ hidden: Bool) {
        isHidden = hidden
        alpha = hidden ? 0 : 1
    }
}

extension UIStackView {
    @discardableResult
    func addArranged(_ views: UIView...) -> UIStackView {
        views.forEach { addArrangedSubview($0) }
        return self
    }

    static func vertical(spacing: CGFloat = 12) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = spacing
        stack.alignment = .fill
        return stack
    }

    static func horizontal(spacing: CGFloat = 10, alignment: UIStackView.Alignment = .center) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = spacing
        stack.alignment = alignment
        return stack
    }
}

extension UIViewController {
    func toast(_ message: String) {
        guard !message.isEmpty else { return }
        HUD.toast(message)
    }

    func showAlert(title: String? = nil,
                   message: String,
                   button: String = "确定",
                   completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: button, style: .default) { _ in completion?() })
        present(alert, animated: true)
    }

    func showConfirm(title: String? = nil,
                     message: String,
                     confirmTitle: String = "确定",
                     cancelTitle: String = "取消",
                     destructive: Bool = false,
                     completion: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle,
                                      style: destructive ? .destructive : .default) { _ in
            completion()
        })
        present(alert, animated: true)
    }

    func prompt(title: String,
                message: String? = nil,
                placeholder: String,
                confirmTitle: String = "确定",
                keyboardType: UIKeyboardType = .default,
                completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = placeholder
            field.keyboardType = keyboardType
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle, style: .default) { _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            completion(text)
        })
        present(alert, animated: true)
    }

    func showError(_ message: String) {
        showAlert(title: "操作失败", message: message)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    func presentCopiedPassword(title: String, password: String, message: String) {
        guard !password.isEmpty else {
            showAlert(title: title, message: message)
            return
        }
        let alert = UIAlertController(title: title, message: "\(message)\n\n密码：\(password)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        alert.addAction(UIAlertAction(title: "复制密码", style: .default) { _ in
            UIPasteboard.general.string = password
            HUD.toast("已复制密码")
        })
        present(alert, animated: true)
    }
}

enum HUD {
    private static weak var overlay: UIView?
    private static var hideWorkItem: DispatchWorkItem?

    static func toast(_ message: String) {
        show(message: message, loading: false)
    }

    static func showLoading(_ message: String) {
        show(message: message, loading: true)
    }

    static func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        overlay?.removeFromSuperview()
        overlay = nil
    }

    private static func show(message: String, loading: Bool) {
        hideWorkItem?.cancel()
        overlay?.removeFromSuperview()

        guard let window = keyWindow else { return }
        let container = UIView()
        container.backgroundColor = UIColor(hex: 0x1F2A37, alpha: 0.94)
        container.layer.cornerRadius = 14
        container.layer.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView.vertical(spacing: 10)
        stack.alignment = .center
        if loading {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = .white
            spinner.startAnimating()
            stack.addArrangedSubview(spinner)
        }
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        stack.addArrangedSubview(label)

        container.addSubview(stack)
        window.addSubview(container)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            container.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: window.centerYAnchor),
            container.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, constant: -60)
        ])
        overlay = container

        if !loading {
            let work = DispatchWorkItem { hide() }
            hideWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

enum QRCodeRenderer {
    static func image(from text: String, size: CGFloat = 240) -> UIImage? {
        let data = Data(text.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension String {
    var digitsOnly: Bool {
        !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MicrophonePermission {
    static func request(completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        @unknown default:
            completion(false)
        }
    }
}
