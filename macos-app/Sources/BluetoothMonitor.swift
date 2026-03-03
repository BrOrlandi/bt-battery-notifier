import Foundation
import IOBluetooth
import os.log

private let logger = Logger(subsystem: "com.brunoorlandi.bt-battery-notifier", category: "monitor")

func logToFile(_ message: String) {
    let path = NSHomeDirectory() + "/Library/Logs/bt-battery.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

class BluetoothMonitor: ObservableObject {
    static let shared = BluetoothMonitor()

    private let pollInterval: TimeInterval = 15.0
    private var timer: Timer?
    private var firstPoll = true
    private let persistenceKey = "cachedDeviceStates"
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [IOBluetoothUserNotification] = []

    // address -> cached device state
    @Published private(set) var state: [String: DeviceState] = [:]

    struct DeviceState: Codable {
        var name: String
        var connected: Bool
        var battery: Int
        var batteryLeft: Int
        var batteryRight: Int
        var batteryCase: Int
        var isMultiBattery: Bool
        var lastBatteryUpdate: Date?
    }

    var knownDevices: [(address: String, name: String)] {
        state.map { (address: $0.key, name: $0.value.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private init() {
        loadPersistedState()
    }

    func start() {
        NSLog("[INFO] Monitor started")
        // Defer first poll to next runloop iteration so the main runloop is running
        // (IOBluetoothDevice.pairedDevices() may block if called before runloop starts)
        DispatchQueue.main.async { [weak self] in
            self?.poll()
            self?.registerBluetoothNotifications()
        }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        connectNotification?.unregister()
        connectNotification = nil
        for n in disconnectNotifications { n.unregister() }
        disconnectNotifications.removeAll()
        NSLog("[INFO] Monitor stopped")
    }

    private func registerBluetoothNotifications() {
        // Register for any device connection events
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))

        // Register disconnect notifications for all currently paired devices
        registerDisconnectForPairedDevices()
    }

    private func registerDisconnectForPairedDevices() {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for device in paired {
            let notification = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
            if let notification = notification {
                disconnectNotifications.append(notification)
            }
        }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.name ?? "Unknown"
        logToFile("[EVENT] Device connected: \(name)")
        // Register disconnect notification for the newly connected device
        if let n = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:))) {
            disconnectNotifications.append(n)
        }
        // Immediate poll to update state and send notifications
        poll()
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.name ?? "Unknown"
        logToFile("[EVENT] Device disconnected: \(name)")
        // Immediate poll to update state and send notifications
        poll()
    }

    private func poll() {
        let devices = BluetoothDevice.scanPairedDevices()

        // Deduplicate by address (keep last)
        var byAddress: [String: BluetoothDevice] = [:]
        for device in devices {
            byAddress[device.address] = device
        }

        let devSummary = byAddress.values.map { "\($0.name)(\($0.connected ? "ON" : "OFF") bat=\($0.batteryPercentSingle)/L\($0.batteryPercentLeft)/R\($0.batteryPercentRight)/C\($0.batteryPercentCase) multi=\($0.isMultiBatteryDevice))" }.joined(separator: ", ")
        logToFile("[POLL] \(byAddress.count) devices: \(devSummary)")

        let settings = Settings.shared

        for (address, raw) in byAddress {
            let prev = state[address]

            // Consider device connected if isConnected() OR has fresh battery reading
            // (some devices like Galaxy Buds report battery but isConnected() returns false)
            let hasFreshReading = raw.batteryPercentSingle > 0
                || raw.batteryPercentLeft > 0
                || raw.batteryPercentRight > 0
                || raw.batteryPercentCase > 0
            let isConnected = raw.connected || hasFreshReading

            var current = DeviceState(
                name: raw.name,
                connected: isConnected,
                battery: raw.batteryPercentSingle,
                batteryLeft: raw.batteryPercentLeft,
                batteryRight: raw.batteryPercentRight,
                batteryCase: raw.batteryPercentCase,
                isMultiBattery: raw.isMultiBatteryDevice
            )

            // Cache battery: carry over previous values when current reports 0,
            // but only if the device was already connected (not a fresh reconnection).
            // On reconnection, start fresh so we don't show stale battery from before charging.
            let wasConnected = prev?.connected == true
            if let prev = prev, wasConnected {
                if current.battery == 0 { current.battery = prev.battery }
                if current.batteryLeft == 0 { current.batteryLeft = prev.batteryLeft }
                if current.batteryRight == 0 { current.batteryRight = prev.batteryRight }
                if current.batteryCase == 0 { current.batteryCase = prev.batteryCase }
            }

            // Track when battery was last read (fresh non-zero reading from device)
            if hasFreshReading {
                current.lastBatteryUpdate = Date()
            } else if let prev = prev, wasConnected {
                current.lastBatteryUpdate = prev.lastBatteryUpdate
            }

            if !firstPoll {
                // Detect disconnection
                if let prev = prev, prev.connected, !current.connected {
                    let batteryText = formatBattery(prev)
                    let mainBattery = getMainBattery(prev)

                    let shouldNotify: Bool
                    if settings.alwaysNotifyOnDisconnect {
                        shouldNotify = true
                    } else if settings.notifyLowBattery {
                        shouldNotify = mainBattery > 0 && mainBattery < settings.batteryThreshold
                    } else {
                        shouldNotify = false
                    }

                    if shouldNotify {
                        let title = L("notification.disconnected", prev.name)
                        let body = batteryText ?? L("notification.battery_unknown")
                        let subtitle: String? = (mainBattery > 0 && mainBattery < settings.batteryThreshold)
                            ? L("notification.low_battery")
                            : nil

                        NSLog("%@", "[INFO] Disconnected: \(prev.name) (\(address)) - \(body)")
                        NotificationManager.shared.send(title: title, body: body, subtitle: subtitle)
                    }
                }

                // Detect connection
                if settings.notifyOnConnect,
                   (prev == nil || !prev!.connected),
                   current.connected {
                    let batteryText = formatBattery(current) ?? L("notification.battery_unknown")
                    let title = L("notification.connected", current.name)
                    NSLog("%@", "[INFO] Connected: \(current.name) (\(address)) - \(batteryText)")
                    NotificationManager.shared.send(title: title, body: batteryText)
                }
            }

            // Log state changes for debugging
            if prev == nil || prev!.battery != current.battery || prev!.connected != current.connected {
                logToFile("[STATE] \(current.name) (\(address)): connected=\(current.connected) bat=\(current.battery) L=\(current.batteryLeft) R=\(current.batteryRight) C=\(current.batteryCase) lastUpdate=\(current.lastBatteryUpdate.map { formatDate($0) } ?? "nil")")
            }

            state[address] = current
        }

        persistState()

        if firstPoll {
            let connected = state.values.filter { $0.connected }
            logToFile("[INIT] \(state.count) devices in state, \(connected.count) connected")
            for (addr, d) in state {
                logToFile("[INIT]   \(d.name) (\(addr)): connected=\(d.connected) bat=\(d.battery) L=\(d.batteryLeft) R=\(d.batteryRight) C=\(d.batteryCase) multi=\(d.isMultiBattery) lastUpdate=\(d.lastBatteryUpdate.map { formatDate($0) } ?? "nil")")
            }
            firstPoll = false
        }
    }

    private func formatBattery(_ device: DeviceState) -> String? {
        if device.isMultiBattery {
            var parts: [String] = []
            if device.batteryLeft > 0 { parts.append(L("battery.left", device.batteryLeft)) }
            if device.batteryRight > 0 { parts.append(L("battery.right", device.batteryRight)) }
            if device.batteryCase > 0 { parts.append(L("battery.case", device.batteryCase)) }
            if !parts.isEmpty { return parts.joined(separator: " | ") }
        }
        if device.battery > 0 { return L("battery.single", device.battery) }
        return nil
    }

    private func getMainBattery(_ device: DeviceState) -> Int {
        if device.isMultiBattery {
            let values = [device.batteryLeft, device.batteryRight, device.batteryCase].filter { $0 > 0 }
            return values.min() ?? 0
        }
        return device.battery
    }

    private func persistState() {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: persistenceKey)
            UserDefaults.standard.synchronize()
        } catch {
            NSLog("%@", "[ERROR] Failed to persist state: \(error)")
        }
    }

    private func loadPersistedState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            logToFile("[LOAD] No persisted device state found")
            return
        }
        logToFile("[LOAD] Found \(data.count) bytes of persisted data")
        do {
            let saved = try JSONDecoder().decode([String: DeviceState].self, from: data)
            // Restore saved state but mark all devices as disconnected
            state = saved.mapValues { device in
                var d = device
                d.connected = false
                return d
            }
            for (address, device) in state {
                let battery = getMainBattery(device)
                let dateStr = device.lastBatteryUpdate.map { formatDate($0) } ?? "unknown"
                logToFile("[LOAD] Restored: \(device.name) (\(address)) battery=\(battery) lastUpdate=\(dateStr)")
            }
        } catch {
            logToFile("[LOAD] ERROR decoding: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }
}
