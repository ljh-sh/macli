import Foundation

enum SmcCmd: Cmd {
    static let meta = CmdMeta(
        name: "smc",
        desc: "Apple Silicon SMC sensors via HID (M1/M2/M3/M4/M5)",
        subcmds: [
            "temp": SmcHidTemp.self,
            "fans": SmcHidFans.self,
            "batt": SmcHidBatt.self,
            "volt": SmcHidVolt.self,
            "curr": SmcHidCurr.self,
            "power": SmcHidPower.self,
            "all": SmcHidAll.self,
        ]
    )
    
    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "Show all sensors (JSON)", cmd: "macli smc all"),
            TldrItem(desc: "Show temperatures (JSON)", cmd: "macli smc temp"),
            TldrItem(desc: "Show temperatures (TSV)", cmd: "macli smc temp --tsv"),
            TldrItem(desc: "Show voltages", cmd: "macli smc volt"),
            TldrItem(desc: "Show currents", cmd: "macli smc curr"),
        ]
    }
}

enum Smc86Cmd: Cmd {
    static let meta = CmdMeta(
        name: "smc86",
        desc: "Intel SMC sensors (legacy, for Intel Macs)",
        subcmds: [
            "temp": Smc86Temp.self,
            "fans": Smc86Fans.self,
            "batt": Smc86Batt.self,
            "volt": Smc86Volt.self,
            "curr": Smc86Curr.self,
            "power": Smc86Power.self,
            "all": Smc86All.self,
        ]
    )
    
    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "Show all sensors (JSON)", cmd: "macli smc86 all"),
            TldrItem(desc: "Show fan speeds", cmd: "macli smc86 fans"),
            TldrItem(desc: "Show battery status", cmd: "macli smc86 batt"),
        ]
    }
}

private func outputSensorsTsv(_ sensors: [[String: Any]], keyField: Bool = false) {
    if keyField {
        print("key\tname\tvalue\tunit")
        for s in sensors {
            let key = s["key"] as? String ?? ""
            let name = s["name"] as? String ?? ""
            let value = s["value"] as? Double ?? 0
            let unit = s["unit"] as? String ?? ""
            print("\(key)\t\(name)\t\(value)\t\(unit)")
        }
    } else {
        print("name\tvalue\tunit")
        for s in sensors {
            let name = s["name"] as? String ?? ""
            let value = s["value"] as? Double ?? 0
            let unit = s["unit"] as? String ?? ""
            print("\(name)\t\(value)\t\(unit)")
        }
    }
}

private func outputJson(data: [String: Any]) {
    print(x.json.stringify(data))
}

private func checkTsv(_ p: ParsedCmd) -> Bool {
    p.opt("--tsv") as Bool? ?? false
}

enum SmcHidTemp: Cmd {
    static let meta = CmdMeta(
        name: "temp",
        desc: "Temperature sensors (PMU tdie, gas gauge, NAND)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let hid = HidSensorCtrl()
            let sensors = hid.getTemperatures().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors)
            } else {
                outputJson(data: [
                    "ok": true,
                    "source": "HID",
                    "sensors": sensors,
                    "count": sensors.count,
                    "note": "Apple Silicon HID thermal sensors only; additional IOKit/SMC sources (e.g. GPU, thermal zones) are not enumerated."
                ])
            }
        }
    )
}

enum SmcHidFans: Cmd {
    static let meta = CmdMeta(
        name: "fans",
        desc: "Fan sensors (Apple Silicon uses passive cooling)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let data: [String: Any] = ["ok": true, "source": "HID", "fans": [] as [[String: Any]], "count": 0, "note": "Apple Silicon uses passive cooling"]
            if checkTsv(p) {
                print("name\tvalue\tunit")
            } else {
                outputJson(data: data)
            }
        }
    )
}

enum SmcHidBatt: Cmd {
    static let meta = CmdMeta(
        name: "batt",
        desc: "Battery status (limited on Apple Silicon)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let data: [String: Any] = ["ok": true, "source": "HID", "note": "Use 'pmset -g batt' for battery info"]
            if checkTsv(p) {
                print("name\tvalue\tunit")
            } else {
                outputJson(data: data)
            }
        }
    )
}

enum SmcHidVolt: Cmd {
    static let meta = CmdMeta(
        name: "volt",
        desc: "Voltage sensors (PMU vldo, vbuck)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let hid = HidSensorCtrl()
            let sensors = hid.getVoltages().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors)
            } else {
                outputJson(data: ["ok": true, "source": "HID", "sensors": sensors, "count": sensors.count])
            }
        }
    )
}

enum SmcHidCurr: Cmd {
    static let meta = CmdMeta(
        name: "curr",
        desc: "Current sensors (PMU ildo, ibuck)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let hid = HidSensorCtrl()
            let sensors = hid.getCurrents().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors)
            } else {
                outputJson(data: ["ok": true, "source": "HID", "sensors": sensors, "count": sensors.count])
            }
        }
    )
}

enum SmcHidPower: Cmd {
    static let meta = CmdMeta(
        name: "power",
        desc: "Power sensors (not available via HID)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let hid = HidSensorCtrl()
            let sensors = hid.getPower().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors)
            } else {
                outputJson(data: ["ok": true, "source": "HID", "sensors": sensors, "count": sensors.count])
            }
        }
    )
}

enum SmcHidAll: Cmd {
    static let meta = CmdMeta(
        name: "all",
        desc: "All sensors: temp, volt, curr, power",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let hid = HidSensorCtrl()
            let temps = hid.getTemperatures().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] }
            let volts = hid.getVoltages().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] }
            let currs = hid.getCurrents().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] }
            let power = hid.getPower().map { ["name": $0.name, "value": $0.value, "unit": $0.unit] }
            
            if checkTsv(p) {
                print("# temperature")
                outputSensorsTsv(temps)
                print("")
                print("# voltage")
                outputSensorsTsv(volts)
                print("")
                print("# current")
                outputSensorsTsv(currs)
                print("")
                print("# power")
                outputSensorsTsv(power)
            } else {
                outputJson(data: [
                    "ok": true,
                    "source": "HID",
                    "temperatures": temps,
                    "fans": [] as [[String: Any]],
                    "battery": ["note": "Use pmset -g batt"] as [String: Any],
                    "voltages": volts,
                    "currents": currs,
                    "power": power,
                ])
            }
        }
    )
}

enum Smc86Temp: Cmd {
    static let meta = CmdMeta(
        name: "temp",
        desc: "Temperature sensors (CPU, GPU, battery)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let smc = SmcCtrl()
            guard smc.open() else {
                let data: [String: Any] = ["ok": false, "error": "Cannot open Intel SMC (not an Intel Mac?)"]
                checkTsv(p) ? print("error\tcannot open Intel SMC") : outputJson(data: data)
                return
            }
            let sensors = smc.getTemperatures().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors, keyField: true)
            } else {
                outputJson(data: ["ok": true, "source": "Intel SMC", "sensors": sensors, "count": sensors.count])
            }
        }
    )
}

enum Smc86Fans: Cmd {
    static let meta = CmdMeta(
        name: "fans",
        desc: "Fan speeds and info",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let smc = SmcCtrl()
            guard smc.open() else {
                let data: [String: Any] = ["ok": false, "error": "Cannot open Intel SMC (not an Intel Mac?)"]
                checkTsv(p) ? print("error\tcannot open Intel SMC") : outputJson(data: data)
                return
            }
            let sensors = smc.getFans().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors, keyField: true)
            } else {
                outputJson(data: ["ok": true, "source": "Intel SMC", "fans": sensors, "count": sensors.count])
            }
        }
    )
}

enum Smc86Batt: Cmd {
    static let meta = CmdMeta(
        name: "batt",
        desc: "Battery status (count, AC power)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let smc = SmcCtrl()
            guard smc.open() else {
                let data: [String: Any] = ["ok": false, "error": "Cannot open Intel SMC (not an Intel Mac?)"]
                checkTsv(p) ? print("error\tcannot open Intel SMC") : outputJson(data: data)
                return
            }
            var data = smc.getBattery()
            data["ok"] = true
            data["source"] = "Intel SMC"
            if checkTsv(p) {
                print("key\tvalue")
                for (k, v) in data { print("\(k)\t\(v)") }
            } else {
                outputJson(data: data)
            }
        }
    )
}

enum Smc86Volt: Cmd {
    static let meta = CmdMeta(
        name: "volt",
        desc: "Voltage sensors (CPU, GPU, rails)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let smc = SmcCtrl()
            guard smc.open() else {
                let data: [String: Any] = ["ok": false, "error": "Cannot open Intel SMC (not an Intel Mac?)"]
                checkTsv(p) ? print("error\tcannot open Intel SMC") : outputJson(data: data)
                return
            }
            let sensors = smc.getVoltages().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors, keyField: true)
            } else {
                outputJson(data: ["ok": true, "source": "Intel SMC", "sensors": sensors, "count": sensors.count])
            }
        }
    )
}

enum Smc86Curr: Cmd {
    static let meta = CmdMeta(
        name: "curr",
        desc: "Current sensors (CPU, GPU)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let smc = SmcCtrl()
            guard smc.open() else {
                let data: [String: Any] = ["ok": false, "error": "Cannot open Intel SMC (not an Intel Mac?)"]
                checkTsv(p) ? print("error\tcannot open Intel SMC") : outputJson(data: data)
                return
            }
            let sensors = smc.getCurrents().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors, keyField: true)
            } else {
                outputJson(data: ["ok": true, "source": "Intel SMC", "sensors": sensors, "count": sensors.count])
            }
        }
    )
}

enum Smc86Power: Cmd {
    static let meta = CmdMeta(
        name: "power",
        desc: "Power sensors (CPU, GPU, package)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let smc = SmcCtrl()
            guard smc.open() else {
                let data: [String: Any] = ["ok": false, "error": "Cannot open Intel SMC (not an Intel Mac?)"]
                checkTsv(p) ? print("error\tcannot open Intel SMC") : outputJson(data: data)
                return
            }
            let sensors = smc.getPower().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] }
            if checkTsv(p) {
                outputSensorsTsv(sensors, keyField: true)
            } else {
                outputJson(data: ["ok": true, "source": "Intel SMC", "sensors": sensors, "count": sensors.count])
            }
        }
    )
}

enum Smc86All: Cmd {
    static let meta = CmdMeta(
        name: "all",
        desc: "All sensors: temp, fans, batt, volt, curr, power",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let smc = SmcCtrl()
            guard smc.open() else {
                let data: [String: Any] = ["ok": false, "error": "Cannot open Intel SMC (not an Intel Mac?)"]
                checkTsv(p) ? print("error\tcannot open Intel SMC") : outputJson(data: data)
                return
            }
            let r = smc.getAll()
            let temps = (r["temperatures"] as? [[String: Any]]) ?? []
            let fans = (r["fans"] as? [[String: Any]]) ?? []
            let volts = (r["voltages"] as? [[String: Any]]) ?? []
            let currs = (r["currents"] as? [[String: Any]]) ?? []
            let power = (r["power"] as? [[String: Any]]) ?? []
            
            if checkTsv(p) {
                print("# temperature")
                outputSensorsTsv(temps, keyField: true)
                print("")
                print("# fans")
                outputSensorsTsv(fans, keyField: true)
                print("")
                print("# voltage")
                outputSensorsTsv(volts, keyField: true)
                print("")
                print("# current")
                outputSensorsTsv(currs, keyField: true)
                print("")
                print("# power")
                outputSensorsTsv(power, keyField: true)
            } else {
                var data: [String: Any] = [
                    "ok": true,
                    "source": "Intel SMC",
                    "temperatures": temps,
                    "fans": fans,
                    "voltages": volts,
                    "currents": currs,
                    "power": power,
                ]
                if let batt = r["battery"] as? [String: Any], !batt.isEmpty {
                    data["battery"] = batt
                }
                outputJson(data: data)
            }
        }
    )
}
