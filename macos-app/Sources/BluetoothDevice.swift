import IOBluetooth
import Foundation

struct BluetoothDevice {
    let name: String
    let address: String
    let connected: Bool
    let batteryPercentSingle: Int
    let batteryPercentLeft: Int
    let batteryPercentRight: Int
    let batteryPercentCase: Int
    let isMultiBatteryDevice: Bool

    var mainBattery: Int {
        if isMultiBatteryDevice {
            let values = [batteryPercentLeft, batteryPercentRight, batteryPercentCase].filter { $0 > 0 }
            return values.min() ?? 0
        }
        return batteryPercentSingle
    }

    func formatBattery() -> String? {
        if isMultiBatteryDevice {
            var parts: [String] = []
            if batteryPercentLeft > 0 { parts.append(L("battery.left", batteryPercentLeft)) }
            if batteryPercentRight > 0 { parts.append(L("battery.right", batteryPercentRight)) }
            if batteryPercentCase > 0 { parts.append(L("battery.case", batteryPercentCase)) }
            if !parts.isEmpty { return parts.joined(separator: " | ") }
        }
        if batteryPercentSingle > 0 { return L("battery.single", batteryPercentSingle) }
        return nil
    }

    // MARK: - IOBluetooth private API battery reading

    private static func readBattery(from device: IOBluetoothDevice) -> (single: Int, left: Int, right: Int, casePct: Int, isMulti: Bool) {
        var single = 0, left = 0, right = 0, casePct = 0
        var isMulti = false

        // Try value(forKey:) first — more reliable for methods returning primitive types (UInt8).
        // perform(selector:) interprets return values as object pointers which can be unreliable
        // for primitives, especially under optimization.
        single = readInt(from: device, key: "batteryPercentSingle")
        left = readInt(from: device, key: "batteryPercentLeft")
        right = readInt(from: device, key: "batteryPercentRight")
        casePct = readInt(from: device, key: "batteryPercentCase")
        isMulti = readInt(from: device, key: "isMultiBatteryDevice") != 0

        // Fallback: try additional selectors if single is still 0
        if single == 0 {
            let combined = readInt(from: device, key: "batteryPercentCombined")
            if combined > 0 { single = combined }
        }
        if single == 0 {
            let headset = readInt(from: device, key: "headsetBattery")
            if headset > 0 { single = headset }
        }

        return (single, left, right, casePct, isMulti)
    }

    private static func readInt(from device: IOBluetoothDevice, key: String) -> Int {
        // value(forKey:) wraps primitive return values in NSNumber automatically
        if device.responds(to: NSSelectorFromString(key)),
           let val = device.value(forKey: key) as? Int {
            return val
        }
        return 0
    }

    // MARK: - system_profiler fallback (for Apple accessories and other devices)

    private static var systemProfilerCache: (devices: [String: SystemProfilerBattery], timestamp: Date)?
    private static let systemProfilerCacheInterval: TimeInterval = 30

    struct SystemProfilerBattery {
        var single: Int = 0
        var left: Int = 0
        var right: Int = 0
        var casePct: Int = 0
    }

    private static func getSystemProfilerBatteries() -> [String: SystemProfilerBattery] {
        // Cache system_profiler results to avoid calling it every poll (~60ms per call)
        if let cache = systemProfilerCache,
           Date().timeIntervalSince(cache.timestamp) < systemProfilerCacheInterval {
            return cache.devices
        }

        var result: [String: SystemProfilerBattery] = [:]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let btData = json["SPBluetoothDataType"] as? [[String: Any]] else {
                return result
            }

            // Look through both connected and disconnected devices
            for entry in btData {
                for key in ["device_connected", "device_not_connected"] {
                    guard let deviceList = entry[key] as? [[String: Any]] else { continue }
                    for deviceDict in deviceList {
                        for (_, info) in deviceDict {
                            guard let props = info as? [String: Any],
                                  let address = props["device_address"] as? String else { continue }

                            var bat = SystemProfilerBattery()
                            if let v = props["device_batteryLevelMain"] as? String {
                                bat.single = Int(v.replacingOccurrences(of: "%", with: "")) ?? 0
                            }
                            if let v = props["device_batteryLevelLeft"] as? String {
                                bat.left = Int(v.replacingOccurrences(of: "%", with: "")) ?? 0
                            }
                            if let v = props["device_batteryLevelRight"] as? String {
                                bat.right = Int(v.replacingOccurrences(of: "%", with: "")) ?? 0
                            }
                            if let v = props["device_batteryLevelCase"] as? String {
                                bat.casePct = Int(v.replacingOccurrences(of: "%", with: "")) ?? 0
                            }

                            let normalizedAddress = address.uppercased().replacingOccurrences(of: "-", with: ":")
                            if bat.single > 0 || bat.left > 0 || bat.right > 0 || bat.casePct > 0 {
                                result[normalizedAddress] = bat
                            }
                        }
                    }
                }
            }
        } catch {
            NSLog("%@", "[ERROR] system_profiler failed: \(error)")
        }

        systemProfilerCache = (devices: result, timestamp: Date())
        return result
    }

    // MARK: - Public scan

    static func scanPairedDevices() -> [BluetoothDevice] {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        // Pre-fetch system_profiler data as fallback
        let profilerBatteries = getSystemProfilerBatteries()

        return pairedDevices.map { device in
            let name = device.name ?? "Unknown"
            let address = device.addressString ?? "Unknown"
            let connected = device.isConnected()

            // Try reading battery from a fresh device object by address lookup
            // pairedDevices() returns cached objects whose battery APIs may return stale data
            var bat = readBattery(from: device)
            if bat.single == 0 && bat.left == 0 && bat.right == 0 && bat.casePct == 0,
               let freshDevice = IOBluetoothDevice(addressString: address) {
                bat = readBattery(from: freshDevice)
            }

            // Fallback to system_profiler data if IOBluetooth returned nothing
            let normalizedAddress = address.uppercased().replacingOccurrences(of: "-", with: ":")
            if bat.single == 0 && bat.left == 0 && bat.right == 0 && bat.casePct == 0,
               let profiler = profilerBatteries[normalizedAddress] {
                if bat.single == 0 { bat.single = profiler.single }
                if bat.left == 0 { bat.left = profiler.left }
                if bat.right == 0 { bat.right = profiler.right }
                if bat.casePct == 0 { bat.casePct = profiler.casePct }
            }

            return BluetoothDevice(
                name: name,
                address: address,
                connected: connected,
                batteryPercentSingle: bat.single,
                batteryPercentLeft: bat.left,
                batteryPercentRight: bat.right,
                batteryPercentCase: bat.casePct,
                isMultiBatteryDevice: bat.isMulti
            )
        }
    }
}
