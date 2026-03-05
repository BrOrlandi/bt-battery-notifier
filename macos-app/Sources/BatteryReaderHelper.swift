// Standalone helper binary that reads battery from IOBluetooth for a given device address.
// Used as a subprocess fallback when the main app's IOBluetooth framework becomes stale.
// Usage: bt-battery-reader <address>
// Output: JSON {"single":60,"left":0,"right":0,"case":0,"multi":false}

import IOBluetooth
import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: bt-battery-reader <address>\n", stderr)
    exit(1)
}

let address = CommandLine.arguments[1]

guard let device = IOBluetoothDevice(addressString: address) else {
    fputs("Device not found: \(address)\n", stderr)
    print("{\"single\":0,\"left\":0,\"right\":0,\"case\":0,\"multi\":false}")
    exit(0)
}

func readInt(_ device: IOBluetoothDevice, _ key: String) -> Int {
    if device.responds(to: NSSelectorFromString(key)),
       let val = device.value(forKey: key) as? Int {
        return val
    }
    return 0
}

let single = readInt(device, "batteryPercentSingle")
let left = readInt(device, "batteryPercentLeft")
let right = readInt(device, "batteryPercentRight")
let casePct = readInt(device, "batteryPercentCase")
let multi = readInt(device, "isMultiBatteryDevice") != 0

print("{\"single\":\(single),\"left\":\(left),\"right\":\(right),\"case\":\(casePct),\"multi\":\(multi)}")
