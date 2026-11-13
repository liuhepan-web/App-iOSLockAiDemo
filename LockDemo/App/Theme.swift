import UIKit

enum Theme {
    static let background = UIColor(hex: 0xF4F6F8)
    static let surface = UIColor.white
    static let header = UIColor(hex: 0x1F2A37)
    static let ink = UIColor(hex: 0x1A1A1A)
    static let secondaryInk = UIColor(hex: 0x5C6670)
    static let mutedInk = UIColor(hex: 0x8A939C)
    static let hairline = UIColor(hex: 0xE4E9ED)
    static let fieldBackground = UIColor(hex: 0xF7F9FA)

    static let wifiAccent = UIColor(hex: 0x0B6E4F)
    static let videoAccent = UIColor(hex: 0x0A6C8F)
    static let bleAccent = UIColor(hex: 0x1B4F72)
    static let online = UIColor(hex: 0x1B8A5A)
    static let offline = UIColor(hex: 0xB00020)

    static let cardRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
    static let pageInset: CGFloat = 20

    static func accent(for kind: LockDeviceKind) -> UIColor {
        switch kind {
        case .wifi: return wifiAccent
        case .video: return videoAccent
        case .photo: return videoAccent
        case .ble: return bleAccent
        case .other: return header
        }
    }

    static func titleFont(_ size: CGFloat = 28) -> UIFont {
        .systemFont(ofSize: size, weight: .bold)
    }

    static func sectionFont() -> UIFont {
        .systemFont(ofSize: 18, weight: .semibold)
    }

    static func bodyFont() -> UIFont {
        .systemFont(ofSize: 15, weight: .regular)
    }

    static func monoFont(_ size: CGFloat = 15, weight: UIFont.Weight = .regular) -> UIFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }

    static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: ink,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: ink,
            .font: UIFont.systemFont(ofSize: 30, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactAppearance = appearance
        }
        UINavigationBar.appearance().tintColor = ink
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(hex & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }
}
