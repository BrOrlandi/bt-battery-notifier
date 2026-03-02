import Cocoa
import SwiftUI

@main
struct BTBatteryApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission
        NotificationManager.shared.requestPermission()

        // Setup menubar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "battery.100.bolt", accessibilityDescription: "BT Battery")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Setup popover with settings
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 220)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SettingsView())

        // Start monitoring
        BluetoothMonitor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        BluetoothMonitor.shared.stop()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Bring popover to front
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
