import Foundation

final class AppConfig {
    static let shared = AppConfig()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let homeId = "lock.demo.homeId"
        static let homeName = "lock.demo.homeName"
        static let homeGeo = "lock.demo.homeGeo"
        static let countryCode = "lock.demo.countryCode"
    }

    private(set) var selectedHome: HomeInfo?

    var countryCode: String {
        get {
            let saved = defaults.string(forKey: Keys.countryCode) ?? ""
            return saved.isEmpty ? "86" : saved
        }
        set {
            defaults.set(newValue.trimmed, forKey: Keys.countryCode)
        }
    }

    var credentialsAvailable: Bool {
        LockSDKSupport.hasCredentials()
    }

    var isLoggedIn: Bool {
        LockSDKSupport.isLoggedIn()
    }

    var userInfo: [String: Any] {
        LockSDKSupport.currentUserInfo()
    }

    var userDisplayName: String {
        let info = userInfo
        for key in ["nickname", "userName", "email", "phoneNumber"] {
            let value = info.string(key)
            if !value.isEmpty { return value }
        }
        return "已登录用户"
    }

    var userAccount: String {
        let info = userInfo
        let email = info.string("email")
        if !email.isEmpty { return email }
        let phone = info.string("phoneNumber")
        if !phone.isEmpty { return phone }
        let name = info.string("userName")
        return name.isEmpty ? info.string("uid") : name
    }

    var userDetail: String {
        let info = userInfo
        let uid = info.string("uid")
        let country = info.string("countryCode")
        var parts: [String] = []
        if !country.isEmpty { parts.append("+\(country)") }
        if !uid.isEmpty { parts.append("uid \(uid)") }
        if let email = nonEmpty(info.string("email")) { parts.append(email) }
        return parts.isEmpty ? userAccount : parts.joined(separator: " · ")
    }

    private init() {
        restoreSelectedHome()
    }

    private func nonEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }

    private func restoreSelectedHome() {
        let homeId = defaults.object(forKey: Keys.homeId) as? NSNumber
        guard let id = homeId?.int64Value, id > 0 else {
            selectedHome = nil
            return
        }
        var dict: [String: Any] = ["homeId": id]
        dict["name"] = defaults.string(forKey: Keys.homeName) ?? ""
        dict["geoName"] = defaults.string(forKey: Keys.homeGeo) ?? ""
        selectedHome = HomeInfo(dict)
    }

    func selectHome(_ home: HomeInfo?) {
        selectedHome = home
        if let home = home {
            defaults.set(NSNumber(value: home.homeId), forKey: Keys.homeId)
            defaults.set(home.name, forKey: Keys.homeName)
            defaults.set(home.geoName, forKey: Keys.homeGeo)
        } else {
            defaults.removeObject(forKey: Keys.homeId)
            defaults.removeObject(forKey: Keys.homeName)
            defaults.removeObject(forKey: Keys.homeGeo)
        }
    }

    func clearSession() {
        selectHome(nil)
    }
}

extension Dictionary where Key == String, Value == Any {
    func lockHome() -> HomeInfo? {
        HomeInfo(self)
    }

    func lockDevice() -> DeviceInfo? {
        DeviceInfo(self)
    }
}
