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

    // Known SMC key registry. The SMC key space on Intel Macs is sparse and model-specific;
    // we keep a curated list and probe each. Modern T2-era Intel Macs (2018+) expose a wider
    // set of keys than the legacy TC0P/TC0D names. The list is grouped by category.
    static let temperatureKeys: [(String, String)] = [
        // Apple Silicon keys (M1/M2/M3 etc.)
        ("Tp09", "P-core 1"), ("Tp0D", "P-core 2"), ("Tp0H", "P-core 3"), ("Tp0L", "P-core 4"),
        ("Tp0P", "P-core 5"), ("Tp0X", "P-core 6"), ("Tp0b", "P-core 7"), ("Tp0f", "P-core 8"),
        ("Tp01", "E-core 1"), ("Tp05", "E-core 2"), ("Tp0T", "E-core 3"),
        ("Tg05", "GPU 1"), ("Tg0D", "GPU 2"), ("Tg0L", "GPU 3"), ("Tg0T", "GPU 4"),
        ("Tm02", "Memory 1"), ("Tm06", "Memory 2"), ("Tm08", "Memory 3"), ("Tm09", "Memory 4"),
        ("PM02", "PMGR"),
        // Legacy Intel keys (Core 2 / early Core i era, ~2010-2013)
        ("TC0P", "CPU Proximity"),
        ("TC0D", "CPU Diode"),
        ("TC0H", "CPU Heatsink"),
        ("TC0E", "CPU Core"),
        ("TG0D", "GPU Diode"),
        ("TG0P", "GPU Proximity"),
        ("TB0T", "Battery"),
        ("TA0P", "Ambient"),
        // Modern Intel keys (T2 era, 2018+ MacBook Pro / iMac / Mac Pro 2019)
        ("TCXC", "CPU Package"), ("TCXc", "CPU Package Core"),
        ("TC1C", "CPU Core 1"), ("TC2C", "CPU Core 2"), ("TC3C", "CPU Core 3"), ("TC4C", "CPU Core 4"),
        ("TC5C", "CPU Core 5"), ("TC6C", "CPU Core 6"), ("TC7C", "CPU Core 7"), ("TC8C", "CPU Core 8"),
        ("TC0c", "CPU Core (alt)"),
        ("TC0p", "CPU Proximity (alt)"),
        ("TC0d", "CPU Diode (alt)"),
        ("TC0h", "CPU Heatsink (alt)"),
        ("TC0e", "CPU Core (alt)"),
        ("TG0E", "GPU Die"), ("TG0p", "GPU Proximity (alt)"),
        ("TG1D", "GPU 1 Diode"), ("TG1P", "GPU 1 Proximity"),
        ("TB0T", "Battery (legacy)"),
        ("TB1T", "Battery Cell 1"), ("TB2T", "Battery Cell 2"), ("TB3T", "Battery Cell 3"),
        ("TB0t", "Battery (alt)"),
        ("TA0p", "Ambient (alt)"),
        ("TM0P", "Memory Proximity 1"), ("TM1P", "Memory Proximity 2"),
        ("TM0S", "Memory Slot 1"), ("TM1S", "Memory Slot 2"),
        ("TM0p", "Memory Proximity (alt)"),
        ("Tp0P", "Platform (legacy)"), ("Tp1P", "Platform 1"), ("Tp2P", "Platform 2"),
        ("Ts0P", "Sensor 0"), ("Ts1P", "Sensor 1"),
        ("Th0H", "Heatsink 0"), ("Th1H", "Heatsink 1"), ("Th2H", "Heatsink 2"),
        ("TN0D", "Northbridge Diode"),
        ("TW0P", "Wi-Fi"),
    ]

    static let voltageKeys: [(String, String)] = [
        ("VC0C", "CPU Core"),
        ("VC0c", "CPU Core (alt)"),
        ("VC1C", "CPU Core 1"), ("VC2C", "CPU Core 2"),
        ("VG0C", "GPU Core"),
        ("VG1C", "GPU Core 1"),
        ("VV1S", "1.1V Rail"),
        ("VV2S", "1.05V Rail"),
        ("VV9S", "0.9V Rail"),
        ("VV0R", "Voltage Rail 0"), ("VV1R", "Voltage Rail 1"), ("VV2R", "Voltage Rail 2"),
        ("VB0R", "Battery Rail"), ("VB1R", "Battery Rail 1"),
        ("Vp0C", "Platform Core"), ("Vp1C", "Platform Core 1"),
    ]

    static let currentKeys: [(String, String)] = [
        ("IC0C", "CPU Core"),
        ("IC0c", "CPU Core (alt)"),
        ("IC1C", "CPU Core 1"),
        ("IG0C", "GPU Core"),
        ("IG1C", "GPU Core 1"),
        ("IB0R", "Battery Rail"), ("IB1R", "Battery Rail 1"),
    ]

    static let powerKeys: [(String, String)] = [
        ("PC0C", "CPU Core"),
        ("PC0c", "CPU Core (alt)"),
        ("PC1C", "CPU Core 1"),
        ("PCPC", "CPU Package"),
        ("PCPG", "CPU Package GPU"),
        ("PG0C", "GPU Core"),
        ("PG1C", "GPU Core 1"),
        ("PSTR", "System Total"),
        ("PPBR", "Package Power Battery Rail"),
        ("Pp0R", "Platform Rail"),
    ]

    func getTemperatures() -> [SmcSensor] {
        var result: [SmcSensor] = []
        for (key, name) in Self.temperatureKeys {
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
        var result: [SmcSensor] = []
        for (key, name) in Self.voltageKeys {
            if let v = readKey(key), v > 0, v < 5 {
                result.append(SmcSensor(key: key, name: name, value: v / 1000.0, unit: "V"))
            }
        }
        return result
    }

    func getCurrents() -> [SmcSensor] {
        var result: [SmcSensor] = []
        for (key, name) in Self.currentKeys {
            if let v = readKey(key), abs(v) > 0.001, abs(v) < 100 {
                result.append(SmcSensor(key: key, name: name, value: v, unit: "A"))
            }
        }
        return result
    }

    func getPower() -> [SmcSensor] {
        var result: [SmcSensor] = []
        for (key, name) in Self.powerKeys {
            if let v = readKey(key), v > 0, v < 500 {
                result.append(SmcSensor(key: key, name: name, value: v / 1000.0, unit: "W"))
            }
        }
        return result
    }

    /// Enumerate SMC key existence by sampling common 1st-byte prefixes and 2nd/3rd/4th bytes.
    /// This is a heuristic — not all 65k possible SMC keys exist, but iterating known
    /// prefixes gives a practical discovery of what's on the host without hardcoding.
    /// Use `enumerateAllKeys(readValues: true)` to also attempt reading each discovered key.
    func enumerateAllKeys(readValues: Bool = false) -> [(key: String, value: Double?)] {
        // First bytes that commonly appear in SMC keys (T/V/I/P/F/B/M/N/H/G/A/C/S/R)
        let firstBytes: [Character] = ["T", "V", "I", "P", "F", "B", "M", "N", "H", "G", "A", "C", "S", "R"]
        // Second bytes: A-Z, 0-9 (covers most)
        let secondBytes: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        // Third bytes: A-Z, 0-9
        let thirdBytes: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        // Fourth bytes: A-Z, 0-9, plus lowercase common letters
        let fourthBytes: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

        var discovered: [(key: String, value: Double?)] = []

        for b1 in firstBytes {
            for b2 in secondBytes {
                for b3 in thirdBytes {
                    for b4 in fourthBytes {
                        let key = "\(b1)\(b2)\(b3)\(b4)"
                        if readValues {
                            if let v = readKey(key) {
                                discovered.append((key, v))
                            }
                        } else {
                            // Just check existence via key info call (faster)
                            if keyExists(key) {
                                discovered.append((key, nil))
                            }
                        }
                    }
                }
            }
        }
        return discovered
    }

    /// Check if an SMC key exists by reading its key info.
    /// Faster than `readKey` (no value fetch), useful for enumeration.
    func keyExists(_ key: String) -> Bool {
        let keyBytes = key.uppercased().utf8
        guard keyBytes.count >= 4 else { return false }
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

        return infoResult == kIOReturnSuccess && output.keyInfo.dataSize > 0
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
