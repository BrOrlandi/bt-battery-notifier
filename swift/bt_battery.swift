import IOBluetooth
import Foundation

struct DeviceInfo: Codable {
    let name: String
    let address: String
    let connected: Bool
    let batteryPercentSingle: Int
    let batteryPercentCombined: Int
    let batteryPercentLeft: Int
    let batteryPercentRight: Int
    let batteryPercentCase: Int
    let isMultiBatteryDevice: Bool
}

var devices: [DeviceInfo] = []

if let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
    for device in pairedDevices {
        let name = device.name ?? "Unknown"
        let address = device.addressString ?? "Unknown"
        let connected = device.isConnected()
        
        var single = 0, combined = 0, left = 0, right = 0, casePct = 0
        var isMulti = false
        
        let selSingle = NSSelectorFromString("batteryPercentSingle")
        let selCombined = NSSelectorFromString("batteryPercentCombined")
        let selLeft = NSSelectorFromString("batteryPercentLeft")
        let selRight = NSSelectorFromString("batteryPercentRight")
        let selCase = NSSelectorFromString("batteryPercentCase")
        let selMulti = NSSelectorFromString("isMultiBatteryDevice")
        
        if device.responds(to: selSingle) {
            single = Int(bitPattern: device.perform(selSingle)?.toOpaque())
        }
        if device.responds(to: selCombined) {
            combined = Int(bitPattern: device.perform(selCombined)?.toOpaque())
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
        
        let info = DeviceInfo(
            name: name,
            address: address,
            connected: connected,
            batteryPercentSingle: single,
            batteryPercentCombined: combined,
            batteryPercentLeft: left,
            batteryPercentRight: right,
            batteryPercentCase: casePct,
            isMultiBatteryDevice: isMulti
        )
        devices.append(info)
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
if let data = try? encoder.encode(devices) {
    print(String(data: data, encoding: .utf8)!)
}
