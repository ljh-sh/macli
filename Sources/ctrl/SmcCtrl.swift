import Foundation
import IOKit

private let KERNEL_INDEX_SMC: UInt32 = 2
private let SMC_CMD_READ_BYTES: UInt8 = 5
private let SMC_CMD_READ_KEYINFO: UInt8 = 9

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers: (UInt8, UInt8, UInt8, UInt8, UInt16) = (0, 0, 0, 0, 0)
    var pLimitData: (UInt16, UInt16, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0)
    var keyInfo: (dataSize: UInt32, dataType: UInt32, dataAttributes: UInt8) = (0, 0, 0)
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

struct SmcSensor {
    var key: String
    var name: String
    var value: Double
    var unit: String
}

class SmcCtrl {
    private var conn: io_connect_t = 0
    private let log = Log.with("SMC")
    
    deinit {
        if conn != 0 {
            IOServiceClose(conn)
        }
    }
    
    func open() -> Bool {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &iterator)
        
        guard result == kIOReturnSuccess else {
            log.d("IOServiceGetMatchingServices failed: \(result)")
            return false
        }
        
        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        
        guard device != 0 else {
            log.d("No AppleSMC found (Apple Silicon uses HID sensors)")
            return false
        }
        
        let openResult = IOServiceOpen(device, mach_task_self_, 0, &conn)
        IOObjectRelease(device)
        
        guard openResult == kIOReturnSuccess else {
            log.d("IOServiceOpen failed: \(openResult)")
            return false
        }
        
        log.i("Intel SMC opened successfully")
        return true
    }
    
    func readKey(_ key: String) -> Double? {
        let keyBytes = key.uppercased().utf8
        guard keyBytes.count >= 4 else { return nil }
        let chars = Array(keyBytes.prefix(4))
        let keyVal = UInt32(chars[0]) << 24 | UInt32(chars[1]) << 16 | UInt32(chars[2]) << 8 | UInt32(chars[3])
        
        var input = SMCKeyData()
        var output = SMCKeyData()
        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size
        
        input.key = keyVal
        input.data8 = SMC_CMD_READ_KEYINFO
        
        let infoResult = withUnsafeMutablePointer(to: &input) { inPtr in
            withUnsafeMutablePointer(to: &output) { outPtr in
                inPtr.withMemoryRebound(to: UInt8.self, capacity: inputSize) { inBytes in
                    outPtr.withMemoryRebound(to: UInt8.self, capacity: outputSize) { outBytes in
                        IOConnectCallStructMethod(conn, KERNEL_INDEX_SMC, inBytes, inputSize, outBytes, &outputSize)
                    }
                }
            }
        }
        
        guard infoResult == kIOReturnSuccess else { return nil }
        
        let dataSize = output.keyInfo.dataSize
        let dataType = output.keyInfo.dataType
        
        input = SMCKeyData()
        output = SMCKeyData()
        input.key = keyVal
        input.keyInfo.dataSize = dataSize
        input.data8 = SMC_CMD_READ_BYTES
        
        let readResult = withUnsafeMutablePointer(to: &input) { inPtr in
            withUnsafeMutablePointer(to: &output) { outPtr in
                inPtr.withMemoryRebound(to: UInt8.self, capacity: inputSize) { inBytes in
                    outPtr.withMemoryRebound(to: UInt8.self, capacity: outputSize) { outBytes in
                        IOConnectCallStructMethod(conn, KERNEL_INDEX_SMC, inBytes, inputSize, outBytes, &outputSize)
                    }
                }
            }
        }
        
        guard readResult == kIOReturnSuccess else { return nil }
        
        let typeStr = withUnsafePointer(to: dataType) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 4) { bytes in
                String(bytes: [bytes[3], bytes[2], bytes[1], bytes[0]], encoding: .ascii) ?? ""
            }
        }
        
        let b = output.bytes
        let bytes = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7,
                     b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15,
                     b.16, b.17, b.18, b.19, b.20, b.21, b.22, b.23,
                     b.24, b.25, b.26, b.27, b.28, b.29, b.30, b.31]
        
        return parseValue(bytes: bytes, type: typeStr, size: Int(dataSize))
    }
    
    private func parseValue(bytes: [UInt8], type: String, size: Int) -> Double? {
        switch type.trimmingCharacters(in: .whitespaces) {
        case "fpe2":
            return Double(UInt16(bytes[0]) << 6 | UInt16(bytes[1]) >> 2)
        case "sp78":
            return Double(Int8(bitPattern: bytes[0]))
        case "sp4b":
            return Double(Int8(bitPattern: bytes[0])) + Double(bytes[1]) / 256.0
        case "fp88":
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 1024.0
        case "ui8":
            return Double(bytes[0])
        case "ui16":
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        case "flt":
            return bytes.withUnsafeBytes { ptr in
                let f = ptr.load(as: Float32.self)
                return Double(f)
            }
        case "flag":
            return Double(bytes[0])
        default:
            if size == 2 {
                return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 256.0
            } else if size == 4 {
                return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
            }
            return nil
        }
    }
    
    // MARK: - High-level APIs
    
    func getTemperatures() -> [SmcSensor] {
        // Apple Silicon keys (different from Intel)
        let sensors: [(String, String)] = [
            // Intel keys
            ("TC0P", "CPU Proximity"),
            ("TC0D", "CPU Diode"),
            ("TC0H", "CPU Heatsink"),
            ("TC0E", "CPU Core"),
            ("TG0D", "GPU Diode"),
            ("TG0P", "GPU Proximity"),
            ("TB0T", "Battery"),
            ("TA0P", "Ambient"),
            // Apple Silicon keys (M1/M2)
            ("Tp09", "P-core 1"), ("Tp0D", "P-core 2"), ("Tp0H", "P-core 3"), ("Tp0L", "P-core 4"),
            ("Tp0P", "P-core 5"), ("Tp0X", "P-core 6"), ("Tp0b", "P-core 7"), ("Tp0f", "P-core 8"),
            ("Tp01", "E-core 1"), ("Tp05", "E-core 2"), ("Tp0T", "E-core 3"),
            ("Tg05", "GPU 1"), ("Tg0D", "GPU 2"), ("Tg0L", "GPU 3"), ("Tg0T", "GPU 4"),
            ("Tm02", "Memory 1"), ("Tm06", "Memory 2"), ("Tm08", "Memory 3"), ("Tm09", "Memory 4"),
            ("PM02", "PMGR"),
        ]
        
        var result: [SmcSensor] = []
        for (key, name) in sensors {
            if let v = readKey(key), v > -100, v < 200, v != 0 {
                result.append(SmcSensor(key: key, name: name, value: v, unit: "°C"))
            }
        }
        return result
    }
    
    func getFans() -> [SmcSensor] {
        var result: [SmcSensor] = []
        
        guard let fanCount = readKey("FNum"), fanCount > 0 else { return result }
        
        for i in 0..<Int(fanCount) {
            let prefix = "F\(i)A"
            if let speed = readKey(prefix + "c"), speed > 0 {
                let name = readKey("F\(i)Id") != nil ? "Fan \(i + 1)" : "Fan \(i + 1)"
                result.append(SmcSensor(key: prefix + "c", name: name, value: speed, unit: "rpm"))
            }
        }
        return result
    }
    
    func getBattery() -> [String: Any] {
        var result: [String: Any] = [:]
        
        if let count = readKey("BNum") {
            result["batteryCount"] = Int(count)
        }
        if let powered = readKey("BATP") {
            result["onACPower"] = powered > 0
        }
        
        return result
    }
    
    func getVoltages() -> [SmcSensor] {
        let sensors: [(String, String)] = [
            ("VC0C", "CPU Core"),
            ("VG0C", "GPU Core"),
            ("VV1S", "1.1V Rail"),
            ("VV2S", "1.05V Rail"),
            ("VV9S", "0.9V Rail"),
        ]
        
        var result: [SmcSensor] = []
        for (key, name) in sensors {
            if let v = readKey(key), v > 0, v < 5 {
                result.append(SmcSensor(key: key, name: name, value: v / 1000.0, unit: "V"))
            }
        }
        return result
    }
    
    func getCurrents() -> [SmcSensor] {
        let sensors: [(String, String)] = [
            ("IC0C", "CPU Core"),
            ("IG0C", "GPU Core"),
        ]
        
        var result: [SmcSensor] = []
        for (key, name) in sensors {
            if let v = readKey(key), abs(v) > 0.001, abs(v) < 100 {
                result.append(SmcSensor(key: key, name: name, value: v, unit: "A"))
            }
        }
        return result
    }
    
    func getPower() -> [SmcSensor] {
        let sensors: [(String, String)] = [
            ("PC0C", "CPU Core"),
            ("PG0C", "GPU Core"),
            ("PCPC", "CPU Package"),
        ]
        
        var result: [SmcSensor] = []
        for (key, name) in sensors {
            if let v = readKey(key), v > 0, v < 500 {
                result.append(SmcSensor(key: key, name: name, value: v / 1000.0, unit: "W"))
            }
        }
        return result
    }
    
    func getAll() -> [String: Any] {
        return [
            "temperatures": getTemperatures().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] },
            "fans": getFans().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] },
            "battery": getBattery(),
            "voltages": getVoltages().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] },
            "currents": getCurrents().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] },
            "power": getPower().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] },
        ]
    }
}
