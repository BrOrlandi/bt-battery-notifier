import Foundation
import Combine
import ServiceManagement

class Settings: ObservableObject {
    static let shared = Settings()

    private enum Keys {
        static let alwaysNotifyOnDisconnect = "alwaysNotifyOnDisconnect"
        static let batteryThreshold = "batteryThreshold"
        static let notifyOnConnect = "notifyOnConnect"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var alwaysNotifyOnDisconnect: Bool {
        didSet { UserDefaults.standard.set(alwaysNotifyOnDisconnect, forKey: Keys.alwaysNotifyOnDisconnect) }
    }

    @Published var batteryThreshold: Int {
        didSet { UserDefaults.standard.set(batteryThreshold, forKey: Keys.batteryThreshold) }
    }

    @Published var notifyOnConnect: Bool {
        didSet { UserDefaults.standard.set(notifyOnConnect, forKey: Keys.notifyOnConnect) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLoginItem()
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        // Register defaults
        defaults.register(defaults: [
            Keys.alwaysNotifyOnDisconnect: true,
            Keys.batteryThreshold: 50,
            Keys.notifyOnConnect: false,
            Keys.launchAtLogin: false,
        ])

        self.alwaysNotifyOnDisconnect = defaults.bool(forKey: Keys.alwaysNotifyOnDisconnect)
        self.batteryThreshold = defaults.integer(forKey: Keys.batteryThreshold)
        self.notifyOnConnect = defaults.bool(forKey: Keys.notifyOnConnect)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[ERROR] Failed to update login item: \(error)")
            }
        }
    }
}
