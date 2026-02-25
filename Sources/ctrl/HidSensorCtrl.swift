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
        let sensors = HidSensorClient.getTemperatures()
        log.d("Got \(sensors.count) temperature sensors from ObjC")
        return sensors.map { HidSensor(name: $0.name, value: $0.value, unit: $0.unit) }
    }
    
    func getVoltages() -> [HidSensor] {
        let sensors = HidSensorClient.getVoltages()
        log.d("Got \(sensors.count) voltage sensors from ObjC")
        return sensors.map { HidSensor(name: $0.name, value: $0.value, unit: $0.unit) }
    }
    
    func getCurrents() -> [HidSensor] {
        let sensors = HidSensorClient.getCurrents()
        log.d("Got \(sensors.count) current sensors from ObjC")
        return sensors.map { HidSensor(name: $0.name, value: $0.value, unit: $0.unit) }
    }
    
    func getPower() -> [HidSensor] {
        return []
    }
    
    func getAll() -> [String: Any] {
        return [
            "temperatures": getTemperatures().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] },
            "fans": [] as [[String: Any]],
            "battery": ["note": "Use IOKit for battery on Apple Silicon"] as [String: Any],
            "voltages": getVoltages().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] },
            "currents": getCurrents().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] },
            "power": [] as [[String: Any]],
        ]
    }
}
