import Foundation
import HidSensorObjC

struct HidSensor {
    var name: String
    var value: Double
    var unit: String
}

class HidSensorCtrl {
    private let log = Log.with("HID")

    func getTemperatures() -> [HidSensor] {
        let sensors = HidSensorClient.getAll()["temperatures"] as? [HidSensorData] ?? []
        log.d("Got \(sensors.count) temperature sensors from ObjC")
        return sensors.map { HidSensor(name: $0.name, value: $0.value, unit: $0.unit) }
    }

    func getVoltages() -> [HidSensor] {
        let sensors = HidSensorClient.getAll()["voltages"] as? [HidSensorData] ?? []
        log.d("Got \(sensors.count) voltage sensors from ObjC")
        return sensors.map { HidSensor(name: $0.name, value: $0.value, unit: $0.unit) }
    }

    func getCurrents() -> [HidSensor] {
        let sensors = HidSensorClient.getAll()["currents"] as? [HidSensorData] ?? []
        log.d("Got \(sensors.count) current sensors from ObjC")
        return sensors.map { HidSensor(name: $0.name, value: $0.value, unit: $0.unit) }
    }

    func getPower() -> [HidSensor] {
        return []
    }

    func getAll() -> [String: Any] {
        let all = HidSensorClient.getAll()
        let temps = (all["temperatures"] as? [HidSensorData])?.map { ["name": $0.name, "value": $0.value, "unit": $0.unit] } ?? []
        let volts = (all["voltages"] as? [HidSensorData])?.map { ["name": $0.name, "value": $0.value, "unit": $0.unit] } ?? []
        let currs = (all["currents"] as? [HidSensorData])?.map { ["name": $0.name, "value": $0.value, "unit": $0.unit] } ?? []

        return [
            "ok": true,
            "source": "HID",
            "temperatures": temps,
            "fans": [] as [[String: Any]],
            "battery": ["note": "Use IOKit for battery on Apple Silicon"] as [String: Any],
            "voltages": volts,
            "currents": currs,
            "power": [] as [[String: Any]],
        ]
    }
}
