import Cocoa
import SwiftUI
import Combine
import CoreBluetooth

@main
struct BTBatteryApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, CBCentralManagerDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var monitorCancellable: AnyCancellable?
    private var settingsCancellable: AnyCancellable?
    private var centralManager: CBCentralManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize CoreBluetooth to ensure Bluetooth authorization is active
        // This triggers the permission dialog if needed and activates the BT stack
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Request notification permission
        NotificationManager.shared.requestPermission()

        // Setup menubar icon with variable length for text
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "BTBatteryNotifier"
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            let btImage = NSImage(systemSymbolName: "bluetooth", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            btImage?.isTemplate = true
            button.image = btImage
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Setup popover with settings
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SettingsView())

        // Start monitoring
        BluetoothMonitor.shared.start()

        // Subscribe to monitor changes to update menubar
        monitorCancellable = BluetoothMonitor.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateMenubar()
                }
            }

        // Subscribe to settings changes to update menubar
        settingsCancellable = Settings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateMenubar()
                }
            }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logToFile("[BT] CBCentralManager state: \(central.state.rawValue) (4=poweredOn, 5=poweredOff)")
        if central.state == .poweredOn {
            logToFile("[BT] Bluetooth authorized and powered on")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        BluetoothMonitor.shared.stop()
        monitorCancellable?.cancel()
        settingsCancellable?.cancel()
    }

    private func updateMenubar() {
        guard let button = statusItem.button else { return }

        let settings = Settings.shared
        let monitor = BluetoothMonitor.shared

        // Always set bluetooth icon as button image
        let btConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let btImage = NSImage(systemSymbolName: "bluetooth", accessibilityDescription: nil)?
            .withSymbolConfiguration(btConfig)
        btImage?.isTemplate = true
        button.image = btImage

        // Collect selected devices that are connected and have battery data
        let connectedDevices: [(String, BluetoothMonitor.DeviceState)] = settings.menubarDeviceAddresses
            .compactMap { address in
                guard let device = monitor.state[address], device.connected else { return nil }
                return (address, device)
            }

        guard !connectedDevices.isEmpty else {
            // Show "BT" text so the widget stays visible and clickable
            button.image = nil
            button.attributedTitle = NSAttributedString(
                string: "BT",
                attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]
            )
            return
        }

        let showIcon = settings.menubarDisplayMode != "percentageOnly"
        let showPercentage = settings.menubarDisplayMode != "iconOnly"

        let fontSize: CGFloat = 12
        let font = NSFont.systemFont(ofSize: fontSize)
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let attrStr = NSMutableAttributedString()

        // Leading space between bluetooth icon and battery info
        attrStr.append(NSAttributedString(string: " ", attributes: [.font: font]))

        for (index, (_, device)) in connectedDevices.enumerated() {
            let battery = device.isMultiBattery
                ? [device.batteryLeft, device.batteryRight, device.batteryCase].filter { $0 > 0 }.min() ?? 0
                : device.battery

            if showIcon {
                let symbolName: String
                switch battery {
                case 0: symbolName = "battery.0"
                case 1...25: symbolName = "battery.25"
                case 26...50: symbolName = "battery.50"
                case 51...75: symbolName = "battery.75"
                default: symbolName = "battery.100"
                }

                if let batteryImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                    .withSymbolConfiguration(symbolConfig) {
                    batteryImage.isTemplate = true
                    let attachment = NSTextAttachment()
                    attachment.image = batteryImage
                    let imageSize = batteryImage.size
                    let yOffset = (font.capHeight - imageSize.height).rounded() / 2
                    attachment.bounds = CGRect(x: 0, y: yOffset, width: imageSize.width, height: imageSize.height)
                    attrStr.append(NSAttributedString(attachment: attachment))
                }
            }

            if showPercentage && battery > 0 {
                let prefix = showIcon ? " " : ""
                attrStr.append(NSAttributedString(string: "\(prefix)\(battery)%", attributes: [.font: font]))
            }

            if index < connectedDevices.count - 1 {
                attrStr.append(NSAttributedString(string: "  ", attributes: [.font: font]))
            }
        }

        button.attributedTitle = attrStr
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Check notification authorization when opening settings
            NotificationManager.shared.checkAuthorizationStatus()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Bring popover to front
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
