import Foundation
import HidSensorObjC

var failures: [String] = []

func check(_ name: String, _ condition: Bool) {
    if !condition {
        failures.append(name)
        print("FAIL: \(name)")
    } else {
        print("PASS: \(name)")
    }
}

func eq<T: Equatable>(_ name: String, _ actual: T?, _ expected: T) {
    check(name, actual == expected)
}

func approx(_ name: String, _ actual: Double?, _ expected: Double, tolerance: Double = 0.001) {
    if let a = actual, abs(a - expected) <= tolerance {
        print("PASS: \(name)")
    } else {
        failures.append(name)
        print("FAIL: \(name) expected ~\(expected), got \(actual ?? .nan)")
    }
}

let snapshot: [String: Any] = [
    "ExternalConnected": true,
    "IsCharging": false,
    "CycleCount": 70,
    "DesignCapacity": 6249,
    "AppleRawMaxCapacity": 6214,
    "AppleRawCurrentCapacity": 6214,
    "NominalChargeCapacity": 6373,
    "Voltage": 13214,
    "Amperage": 0,
    "InstantAmperage": 50,
    "Temperature": 3019,
    "VirtualTemperature": 2900,
    "TimeRemaining": 65535,
    "AvgTimeToEmpty": 65535,
    "AvgTimeToFull": 65535,
    "Serial": "S12345",
    "DeviceName": "bq40z651",
    "BatteryData": [
        "CellVoltage": [4407, 4403, 4404],
        "Qmax": [6661, 6678, 6667],
        "ManufactureDate": 57386017502003,
        "Serial": "B12345",
        "DesignCapacity": 6249,
        "CycleCount": 70,
        "Voltage": 13214,
        "MaxCapacity": 100,
    ],
    "AdapterDetails": [
        "Watts": 60,
        "Voltage": 20000,
        "Current": 3000,
        "Description": "pd charger",
    ],
    "PowerTelemetryData": [
        "SystemPowerIn": 4469,
        "BatteryPower": 0,
        "SystemVoltageIn": 20225,
        "SystemCurrentIn": 220,
    ],
    "ChargerData": [
        "ChargingVoltage": 4457,
        "ChargingCurrent": 0,
    ],
]

let info = BatteryClient.parseBatteryInfo(fromSnapshot: snapshot)

eq("present", info["present"] as? Bool, true)
eq("source", info["source"] as? String, "IOKit")
eq("status", info["status"] as? String, "AC")
eq("externalConnected", info["externalConnected"] as? Bool, true)
eq("isCharging", info["isCharging"] as? Bool, false)

eq("cycleCount", info["cycleCount"] as? Int, 70)
eq("designCapacity", info["designCapacity"] as? Int, 6249)
eq("maxCapacity", info["maxCapacity"] as? Int, 6214)
eq("currentCapacity", info["currentCapacity"] as? Int, 6214)
eq("nominalChargeCapacity", info["nominalChargeCapacity"] as? Int, 6373)

eq("voltage", info["voltage"] as? Int, 13214)
eq("amperage", info["amperage"] as? Int, 0)
eq("instantAmperage", info["instantAmperage"] as? Int, 50)

approx("temperature", info["temperature"] as? Double, 30.19)
approx("virtualTemperature", info["virtualTemperature"] as? Double, 29.0)

eq("timeRemaining", info["timeRemaining"] as? Int, 65535)
eq("avgTimeToEmpty", info["avgTimeToEmpty"] as? Int, 65535)
eq("avgTimeToFull", info["avgTimeToFull"] as? Int, 65535)

eq("serialNumber", info["serialNumber"] as? String, "S12345")
eq("deviceName", info["deviceName"] as? String, "bq40z651")

approx("healthPercent", info["healthPercent"] as? Double, 6214.0 / 6249.0 * 100.0, tolerance: 0.01)
approx("designWh", info["designWh"] as? Double, 13214.0 * 6249.0 / 1000000.0)
approx("currentWh", info["currentWh"] as? Double, 13214.0 * 6214.0 / 1000000.0)

eq("cellVoltages", info["cellVoltages"] as? [Double], [4.407, 4.403, 4.404])
eq("qmax", info["qmax"] as? [Int], [6661, 6678, 6667])
eq("manufactureDate", info["manufactureDate"] as? Int, 57386017502003)
eq("batterySerial", info["batterySerial"] as? String, "B12345")

eq("inputPower", info["inputPower"] as? Int, 60)
approx("systemPower", info["systemPower"] as? Double, 4.469)
approx("batteryPower", info["batteryPower"] as? Double, 0.0)
eq("systemVoltageIn", info["systemVoltageIn"] as? Int, 20225)
eq("systemCurrentIn", info["systemCurrentIn"] as? Int, 220)

let adapter = info["adapter"] as? [String: Any]
eq("adapter.watts", adapter?["watts"] as? Int, 60)
eq("adapter.voltage", adapter?["voltage"] as? Int, 20000)
eq("adapter.current", adapter?["current"] as? Int, 3000)
eq("adapter.description", adapter?["description"] as? String, "pd charger")

let charger = info["charger"] as? [String: Any]
eq("charger.voltage", charger?["voltage"] as? Int, 4457)
eq("charger.current", charger?["current"] as? Int, 0)

let empty = BatteryClient.parseBatteryInfo(fromSnapshot: [:])
eq("empty present", empty["present"] as? Bool, true)
check("empty cycleCount nil", empty["cycleCount"] == nil)

if failures.isEmpty {
    print("\nAll tests passed.")
    exit(0)
} else {
    print("\n\(failures.count) test(s) failed.")
    exit(1)
}
