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
            if batteryPercentLeft > 0 { parts.append("E: \(batteryPercentLeft)%") }
            if batteryPercentRight > 0 { parts.append("D: \(batteryPercentRight)%") }
            if batteryPercentCase > 0 { parts.append("Estojo: \(batteryPercentCase)%") }
            if !parts.isEmpty { return parts.joined(separator: " | ") }
        }
        if batteryPercentSingle > 0 { return "Bateria: \(batteryPercentSingle)%" }
        return nil
    }

    private static func readBattery(from device: IOBluetoothDevice) -> (single: Int, left: Int, right: Int, casePct: Int, isMulti: Bool) {
        var single = 0, left = 0, right = 0, casePct = 0
        var isMulti = false

        let selSingle = NSSelectorFromString("batteryPercentSingle")
        let selLeft = NSSelectorFromString("batteryPercentLeft")
        let selRight = NSSelectorFromString("batteryPercentRight")
        let selCase = NSSelectorFromString("batteryPercentCase")
        let selMulti = NSSelectorFromString("isMultiBatteryDevice")

        if device.responds(to: selSingle) {
            single = Int(bitPattern: device.perform(selSingle)?.toOpaque())
        }
        if device.responds(to: selLeft) {
            left = Int(bitPattern: device.perform(selLeft)?.toOpaque())
        }
        if device.responds(to: selRight) {
            right = Int(bitPattern: device.perform(selRight)?.toOpaque())
        }
        if device.responds(to: selCase) {
            casePct = Int(bitPattern: device.perform(selCase)?.toOpaque())
        }
        if device.responds(to: selMulti) {
            isMulti = Int(bitPattern: device.perform(selMulti)?.toOpaque()) != 0
        }

        return (single, left, right, casePct, isMulti)
    }

    static func scanPairedDevices() -> [BluetoothDevice] {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

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
