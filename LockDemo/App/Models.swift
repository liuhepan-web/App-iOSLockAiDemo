import Foundation

enum LockDeviceKind: String {
    case wifi
    case video
    case photo
    case ble
    case other = "unknown"

    init(raw: String?) {
        self = LockDeviceKind(rawValue: (raw ?? "").lowercased()) ?? .other
    }

    var title: String {
        switch self {
        case .wifi: return "Wi-Fi 门锁"
        case .video: return "可视门锁"
        case .photo: return "拍照锁"
        case .ble: return "蓝牙门锁"
        case .other: return "其他设备"
        }
    }

    var badge: String {
        switch self {
        case .wifi: return "WIFI LOCK PANEL"
        case .video: return "VIDEO LOCK · BASE API + AV"
        case .photo: return "PHOTO LOCK · BASE API"
        case .ble: return "BLE LOCK PANEL"
        case .other: return "LOCK PANEL"
        }
    }

    var symbolName: String {
        switch self {
        case .wifi: return "wifi"
        case .video: return "video.fill"
        case .photo: return "camera.fill"
        case .ble: return "dot.radiowaves.left.and.right"
        case .other: return "lock.fill"
        }
    }

    var supportsPreview: Bool {
        self == .video || self == .photo
    }
}

struct HomeInfo {
    let homeId: Int64
    let name: String
    let geoName: String

    init?(_ dict: [String: Any]) {
        guard let homeId = dict.int64("homeId"), homeId > 0 else { return nil }
        self.homeId = homeId
        let name = dict.string("name")
        self.name = name.isEmpty ? "家庭 \(homeId)" : name
        self.geoName = dict.string("geoName")
    }

    var subtitle: String {
        geoName.isEmpty ? "homeId \(homeId)" : "\(geoName) · homeId \(homeId)"
    }
}

struct DeviceInfo {
    let devId: String
    let name: String
    let categoryCode: String
    let productId: String
    let homeId: Int64
    let isOnline: Bool
    let kind: LockDeviceKind

    init?(_ dict: [String: Any]) {
        let devId = dict.string("devId")
        guard !devId.isEmpty else { return nil }
        self.devId = devId
        let name = dict.string("name")
        self.name = name.isEmpty ? devId : name
        self.categoryCode = dict.string("categoryCode")
        self.productId = dict.string("productId")
        self.homeId = dict.int64("homeId") ?? 0
        self.isOnline = dict.bool("isOnline")
        self.kind = LockDeviceKind(raw: dict.string("kind"))
    }

    var meta: String {
        var parts: [String] = [kind.title]
        if !categoryCode.isEmpty { parts.append("categoryCode: \(categoryCode)") }
        if !productId.isEmpty { parts.append("productId: \(productId)") }
        parts.append("devId: \(devId)")
        return parts.joined(separator: "\n")
    }
}

struct MemberInfo {
    let userId: String
    let name: String
    let contact: String
    let avatarUrl: String
    let lockUserId: Int
    let userType: Int
    let isAdmin: Bool
    let unlockSummary: String

    init?(_ dict: [String: Any]) {
        let userId = dict.string("userId")
        guard !userId.isEmpty else { return nil }
        self.userId = userId
        let name = dict.string("name")
        self.name = name.isEmpty ? userId : name
        self.contact = dict.string("contact")
        self.avatarUrl = dict.string("avatarUrl")
        self.lockUserId = dict.int("lockUserId") ?? 0
        self.userType = dict.int("userType") ?? 0
        self.isAdmin = dict.bool("isAdmin")
        self.unlockSummary = dict.string("unlockSummary")
    }

    var meta: String {
        "userId: \(userId)  lockUserId: \(lockUserId)  userType: \(userType)"
    }
}

struct PasswordInfo {
    let name: String
    let code: String
    let identifier: Int
    let sn: Int
    let type: String
    let effectiveTime: Int64
    let invalidTime: Int64
    let phase: Int

    init(_ dict: [String: Any]) {
        let name = dict.string("name")
        self.name = name.isEmpty ? "密码" : name
        self.code = dict.string("code")
        self.identifier = dict.int("identifier") ?? 0
        self.sn = dict.int("sn") ?? 0
        let type = dict.string("type")
        self.type = type.isEmpty ? "密码" : type
        self.effectiveTime = dict.int64("effectiveTime") ?? 0
        self.invalidTime = dict.int64("invalidTime") ?? 0
        self.phase = dict.int("phase") ?? 0
    }

    var validity: String {
        if invalidTime <= 0 { return "长期有效" }
        return "至 \(DateFormatter.lockDateTime.string(from: Date(timeIntervalSince1970: TimeInterval(invalidTime) / 1000)))"
    }

    var detail: String {
        var parts: [String] = [type]
        if identifier > 0 { parts.append("编号 \(identifier)") }
        if sn > 0 { parts.append("SN \(sn)") }
        parts.append(validity)
        return parts.joined(separator: " · ")
    }
}

struct RecordInfo {
    let userName: String
    let userId: String
    let avatarUrl: String
    let time: Int64
    let status: Int

    init(_ dict: [String: Any]) {
        let name = dict.string("userName")
        self.userName = name.isEmpty ? "门锁记录" : name
        self.userId = dict.string("userId")
        self.avatarUrl = dict.string("avatarUrl")
        self.time = dict.int64("time") ?? 0
        self.status = dict.int("status") ?? 0
    }

    var timeText: String {
        guard time > 0 else { return "-" }
        return DateFormatter.lockDateTime.string(from: Date(timeIntervalSince1970: TimeInterval(time) / 1000))
    }

    var statusText: String {
        status == 0 ? "开锁记录" : "状态 \(status)"
    }
}

struct BLEDeviceInfo {
    let uuid: String
    let name: String
    let productId: String
    let mac: String

    init?(_ dict: [String: Any]) {
        let uuid = dict.string("uuid")
        guard !uuid.isEmpty else { return nil }
        self.uuid = uuid
        let name = dict.string("name")
        self.name = name.isEmpty ? "蓝牙门锁" : name
        self.productId = dict.string("productId")
        self.mac = dict.string("mac")
    }
}

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String {
        guard let value = self[key], !(value is NSNull) else { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    func int(_ key: String) -> Int? {
        int64(key).map(Int.init)
    }

    func int64(_ key: String) -> Int64? {
        guard let value = self[key], !(value is NSNull) else { return nil }
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String { return Int64(string) }
        return nil
    }

    func bool(_ key: String) -> Bool {
        guard let value = self[key], !(value is NSNull) else { return false }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String { return (string as NSString).boolValue }
        return false
    }
}

extension DateFormatter {
    static let lockDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
