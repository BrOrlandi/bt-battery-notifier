import Foundation
import Combine
import ServiceManagement

class Settings: ObservableObject {
    static let shared = Settings()

    private enum Keys {
        static let alwaysNotifyOnDisconnect = "alwaysNotifyOnDisconnect"
        static let batteryThreshold = "batteryThreshold"
        static let notifyOnConnect = "notifyOnConnect"
        static let notifyLowBattery = "notifyLowBattery"
        static let launchAtLogin = "launchAtLogin"
        static let menubarDeviceAddresses = "menubarDeviceAddresses"
        static let menubarDisplayMode = "menubarDisplayMode"
        // Legacy
        static let pinnedDeviceAddress = "pinnedDeviceAddress"
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

    @Published var notifyLowBattery: Bool {
        didSet { UserDefaults.standard.set(notifyLowBattery, forKey: Keys.notifyLowBattery) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLoginItem()
        }
    }

    @Published var menubarDeviceAddresses: [String] {
        didSet { UserDefaults.standard.set(menubarDeviceAddresses, forKey: Keys.menubarDeviceAddresses) }
    }

    @Published var menubarDisplayMode: String {
        didSet { UserDefaults.standard.set(menubarDisplayMode, forKey: Keys.menubarDisplayMode) }
    }

    private init() {
        let defaults = UserDefaults.standard

        // Register defaults
        defaults.register(defaults: [
            Keys.alwaysNotifyOnDisconnect: true,
            Keys.batteryThreshold: 50,
            Keys.notifyOnConnect: false,
            Keys.notifyLowBattery: true,
            Keys.launchAtLogin: false,
            Keys.menubarDisplayMode: "iconAndPercentage",
        ])

        self.alwaysNotifyOnDisconnect = defaults.bool(forKey: Keys.alwaysNotifyOnDisconnect)
        self.batteryThreshold = defaults.integer(forKey: Keys.batteryThreshold)
        self.notifyOnConnect = defaults.bool(forKey: Keys.notifyOnConnect)
        self.notifyLowBattery = defaults.bool(forKey: Keys.notifyLowBattery)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.menubarDeviceAddresses = defaults.stringArray(forKey: Keys.menubarDeviceAddresses) ?? []
        self.menubarDisplayMode = defaults.string(forKey: Keys.menubarDisplayMode) ?? "iconAndPercentage"

        // Migrate from legacy pinnedDeviceAddress
        if menubarDeviceAddresses.isEmpty,
           let legacy = defaults.string(forKey: Keys.pinnedDeviceAddress) {
            menubarDeviceAddresses = [legacy]
            defaults.removeObject(forKey: Keys.pinnedDeviceAddress)
        }
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
                NSLog("[ERROR] Failed to update login item: \(error)")
            }
        }
    }
}
