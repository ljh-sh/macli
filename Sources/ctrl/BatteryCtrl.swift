import Foundation
import HidSensorObjC

class BatteryCtrl {
    func getBattery() -> [String: Any] {
        return BatteryClient.getBatteryInfo()
    }

    func getSnapshot() -> [String: Any]? {
        return BatteryClient.getBatterySnapshot()
    }

    /// Power readings suitable for the monitor stream.
    func getPowerMetrics() -> [(name: String, value: Double, unit: String)] {
        let info = BatteryClient.getBatteryInfo()
        guard (info["present"] as? Bool) == true else { return [] }

        var result: [(name: String, value: Double, unit: String)] = []
        if let systemPower = info["systemPower"] as? Double {
            result.append((name: "System Power", value: systemPower, unit: "W"))
        }
        if let batteryPower = info["batteryPower"] as? Double {
            result.append((name: "Battery Power", value: batteryPower, unit: "W"))
        }
        if let inputPower = info["inputPower"] as? Double {
            result.append((name: "Input Power", value: inputPower, unit: "W"))
        }
        return result
    }
}
