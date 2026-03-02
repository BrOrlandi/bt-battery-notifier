import Foundation

class BluetoothMonitor: ObservableObject {
    static let shared = BluetoothMonitor()

    private let pollInterval: TimeInterval = 15.0
    private var timer: Timer?
    private var firstPoll = true

    // address -> cached device state
    private var state: [String: DeviceState] = [:]

    struct DeviceState {
        var name: String
        var connected: Bool
        var battery: Int
        var batteryLeft: Int
        var batteryRight: Int
        var batteryCase: Int
        var isMultiBattery: Bool
    }

    private init() {}

    func start() {
        print("[INFO] Monitor started")
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        print("[INFO] Monitor stopped")
    }

    private func poll() {
        let devices = BluetoothDevice.scanPairedDevices()

        // Deduplicate by address (keep last)
        var byAddress: [String: BluetoothDevice] = [:]
        for device in devices {
            byAddress[device.address] = device
        }

        let settings = Settings.shared

        for (address, raw) in byAddress {
            let prev = state[address]

            var current = DeviceState(
                name: raw.name,
                connected: raw.connected,
                battery: raw.batteryPercentSingle,
                batteryLeft: raw.batteryPercentLeft,
                batteryRight: raw.batteryPercentRight,
                batteryCase: raw.batteryPercentCase,
                isMultiBattery: raw.isMultiBatteryDevice
            )

            // Cache battery: only update if new value > 0
            if let prev = prev, current.connected {
                if current.battery == 0 { current.battery = prev.battery }
                if current.batteryLeft == 0 { current.batteryLeft = prev.batteryLeft }
                if current.batteryRight == 0 { current.batteryRight = prev.batteryRight }
                if current.batteryCase == 0 { current.batteryCase = prev.batteryCase }
            }

            if !firstPoll {
                // Detect disconnection
                if let prev = prev, prev.connected, !current.connected {
                    let batteryText = formatBattery(prev)
                    let mainBattery = getMainBattery(prev)

                    let shouldNotify: Bool
                    if settings.alwaysNotifyOnDisconnect {
                        shouldNotify = true
                    } else {
                        shouldNotify = mainBattery > 0 && mainBattery < settings.batteryThreshold
                    }

                    if shouldNotify {
                        let title = "\(prev.name) desconectado"
                        let body = batteryText ?? "Bateria: desconhecida"
                        let subtitle: String? = (mainBattery > 0 && mainBattery < settings.batteryThreshold)
                            ? "Bateria baixa - coloque para carregar!"
                            : nil

                        print("[INFO] Disconnected: \(prev.name) (\(address)) - \(body)")
                        NotificationManager.shared.send(title: title, body: body, subtitle: subtitle)
                    }
                }

                // Detect connection
                if settings.notifyOnConnect,
                   (prev == nil || !prev!.connected),
                   current.connected {
                    let batteryText = formatBattery(current) ?? "Bateria: desconhecida"
                    let title = "\(current.name) conectado"
                    print("[INFO] Connected: \(current.name) (\(address)) - \(batteryText)")
                    NotificationManager.shared.send(title: title, body: batteryText)
                }
            }

            state[address] = current
        }

        if firstPoll {
            let connected = state.values.filter { $0.connected }
            print("[INFO] Initial poll: \(state.count) devices found, \(connected.count) connected")
            for d in connected {
                print("[INFO]   - \(d.name): \(d.battery)%")
            }
            firstPoll = false
        }
    }

    private func formatBattery(_ device: DeviceState) -> String? {
        if device.isMultiBattery {
            var parts: [String] = []
            if device.batteryLeft > 0 { parts.append("E: \(device.batteryLeft)%") }
            if device.batteryRight > 0 { parts.append("D: \(device.batteryRight)%") }
            if device.batteryCase > 0 { parts.append("Estojo: \(device.batteryCase)%") }
            if !parts.isEmpty { return parts.joined(separator: " | ") }
        }
        if device.battery > 0 { return "Bateria: \(device.battery)%" }
        return nil
    }

    private func getMainBattery(_ device: DeviceState) -> Int {
        if device.isMultiBattery {
            let values = [device.batteryLeft, device.batteryRight, device.batteryCase].filter { $0 > 0 }
            return values.min() ?? 0
        }
        return device.battery
    }
}
