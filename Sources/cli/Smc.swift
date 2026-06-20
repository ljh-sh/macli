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
            "keys": Smc86Keys.self,
            "info": Smc86Info.self,
        ]
    )

    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "Show all sensors (JSON)", cmd: "macli smc86 all"),
            TldrItem(desc: "Show fan speeds", cmd: "macli smc86 fans"),
            TldrItem(desc: "Show battery status", cmd: "macli smc86 batt"),
            TldrItem(desc: "Enumerate all available SMC keys", cmd: "macli smc86 keys"),
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

func outputJson(data: [String: Any]) {
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
        desc: "Battery status via IOKit",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let data = BatteryCtrl().getBattery()
            if checkTsv(p) {
                print("name\tvalue\tunit")
                for (key, value) in data.sorted(by: { $0.key < $1.key }) {
                    if key == "source" || key == "present" || key == "status" { continue }
                    if let num = value as? NSNumber {
                        print("\(key)\t\(num)\t")
                    } else if let str = value as? String {
                        print("\(key)\t\(str)\t")
                    } else if let bool = value as? Bool {
                        print("\(key)\t\(bool)\t")
                    }
                }
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
        desc: "Power sensors via IOKit",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let data = PowerCtrl().getPower()
            if checkTsv(p) {
                if let sensors = data["sensors"] as? [[String: Any]] {
                    outputSensorsTsv(sensors)
                } else {
                    print("name\tvalue\tunit")
                }
            } else {
                outputJson(data: data)
            }
        }
    )
}

enum SmcHidAll: Cmd {
    static let meta = CmdMeta(
        name: "all",
        desc: "All sensors: temp, volt, curr, power, battery",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            let hid = HidSensorCtrl()
            let all = hid.getAll()
            let temps = (all["temperatures"] as? [[String: Any]]) ?? []
            let volts = (all["voltages"] as? [[String: Any]]) ?? []
            let currs = (all["currents"] as? [[String: Any]]) ?? []
            let powerInfo = (all["power"] as? [String: Any])
            let powerSensors = (powerInfo?["sensors"] as? [[String: Any]]) ?? []

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
                outputSensorsTsv(powerSensors)
            } else {
                outputJson(data: all)
            }
        }
    )
}

enum Smc86Temp: Cmd {
    static let meta = CmdMeta(
        name: "temp",
        desc: "Temperature sensors (CPU, GPU, battery, PMU tdev/tdie/tcal via HID bridge)",
        opts: [OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV instead of JSON")],
        run: { p in
            var sensors: [[String: Any]] = []
            var sources: [String] = []
            var smcOpened = false

            // Direct AppleSMC path
            let smc = SmcCtrl()
            if smc.open() {
                smcOpened = true
                let direct = smc.getTemperatures().map { ["key": $0.key, "name": $0.name, "value": $0.value, "unit": $0.unit] }
                sensors.append(contentsOf: direct)
                if !direct.isEmpty { sources.append("Intel SMC") }
            }

            // HID bridge fallback (modern Intel T2-era PMU tdev/tdie/tcal sensors)
            let hid = HidSensorCtrl()
            let hidSensors = hid.getTemperatures().map { sensor -> [String: Any] in
                ["key": "HID:\(sensor.name)", "name": sensor.name, "value": sensor.value, "unit": sensor.unit]
            }
            // Dedup by name (HID sensors can overlap with SMC direct)
            let existingNames = Set(sensors.compactMap { $0["name"] as? String })
            let newHid = hidSensors.filter { !existingNames.contains($0["name"] as? String ?? "") }
            sensors.append(contentsOf: newHid)
            if !newHid.isEmpty { sources.append("HID") }

            if checkTsv(p) {
                outputSensorsTsv(sensors, keyField: true)
            } else {
                if sensors.isEmpty {
                    let hint = smcOpened
                        ? "Intel SMC opened but no recognized temperature keys; HID bridge returned no sensors. Host may be a pre-T2 Intel Mac, or no thermal sensors are exposed. Try `macli smc86 keys --read` to see all detected keys."
                        : "Cannot open Intel SMC (not an Intel Mac?)"
                    outputJson(data: ["ok": false, "error": hint, "sources": sources, "smcAvailable": smcOpened])
                } else {
                    outputJson(data: ["ok": true, "sources": sources, "sensors": sensors, "count": sensors.count])
                }
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

enum Smc86Keys: Cmd {
    static let meta = CmdMeta(
        name: "keys",
        desc: "Enumerate all available Intel SMC keys (4-char ASCII). Use --read to also fetch values.",
        opts: [OptMeta(name: "--read", type: Bool.self, desc: "Also attempt to read each key's value")],
        run: { p in
            let smc = SmcCtrl()
            guard smc.open() else {
                let data: [String: Any] = ["ok": false, "error": "Cannot open Intel SMC (not an Intel Mac?)"]
                outputJson(data: data)
                return
            }

            let doRead = p.opt("--read") as Bool? ?? false
            // Use category-grouped key lists for quick discovery (not full brute-force enumeration)
            // to avoid slow full 26-letter sweeps.
            var discovered: [String: [String: Any]] = [:]

            // Probe each curated key; report only existing
            for (key, name) in SmcCtrl.temperatureKeys {
                if smc.keyExists(key) {
                    var entry: [String: Any] = ["name": name, "category": "temperature"]
                    if doRead, let v = smc.readKey(key) {
                        entry["value"] = v
                    }
                    discovered[key] = entry
                }
            }
            for (key, name) in SmcCtrl.voltageKeys {
                if smc.keyExists(key) {
                    var entry: [String: Any] = ["name": name, "category": "voltage"]
                    if doRead, let v = smc.readKey(key) {
                        entry["value"] = v
                    }
                    discovered[key] = entry
                }
            }
            for (key, name) in SmcCtrl.currentKeys {
                if smc.keyExists(key) {
                    var entry: [String: Any] = ["name": name, "category": "current"]
                    if doRead, let v = smc.readKey(key) {
                        entry["value"] = v
                    }
                    discovered[key] = entry
                }
            }
            for (key, name) in SmcCtrl.powerKeys {
                if smc.keyExists(key) {
                    var entry: [String: Any] = ["name": name, "category": "power"]
                    if doRead, let v = smc.readKey(key) {
                        entry["value"] = v
                    }
                    discovered[key] = entry
                }
            }
            // Probe common fan / battery keys
            for key in ["FNum", "F0Ac", "F1Ac", "F2Ac", "BNum", "BATP", "MSDI"] {
                if smc.keyExists(key) {
                    var entry: [String: Any] = ["name": key, "category": "system"]
                    if doRead, let v = smc.readKey(key) {
                        entry["value"] = v
                    }
                    discovered[key] = entry
                }
            }

            // Print
            if doRead {
                print("key\tname\tcategory\tvalue")
                for (key, entry) in discovered.sorted(by: { $0.key < $1.key }) {
                    let name = entry["name"] as? String ?? ""
                    let cat = entry["category"] as? String ?? ""
                    if let v = entry["value"] {
                        print("\(key)\t\(name)\t\(cat)\t\(v)")
                    } else {
                        print("\(key)\t\(name)\t\(cat)\t")
                    }
                }
            } else {
                let keysList = discovered.keys.sorted()
                for key in keysList {
                    let entry = discovered[key]!
                    let name = entry["name"] as? String ?? ""
                    let cat = entry["category"] as? String ?? ""
                    print("\(key)\t\(name)\t\(cat)")
                }
                if keysList.isEmpty {
                    print("(no recognized SMC keys found on this host)")
                }
            }
        }
    )
}

enum Smc86Info: Cmd {
    static let meta = CmdMeta(
        name: "info",
        desc: "Intel SMC summary: connection status, key counts by category, host hints.",
        run: { _ in
            let smc = SmcCtrl()
            let opened = smc.open()

            var data: [String: Any] = [
                "ok": opened,
                "host": "Intel Mac",
                "smcAvailable": opened,
            ]

            if opened {
                var counts: [String: Int] = [
                    "temperature": smc.getTemperatures().count,
                    "fans": smc.getFans().count,
                    "voltage": smc.getVoltages().count,
                    "current": smc.getCurrents().count,
                    "power": smc.getPower().count,
                ]
                let bat = smc.getBattery()
                if let n = bat["batteryCount"] as? Int, n > 0 {
                    counts["battery"] = n
                }
                data["keyCounts"] = counts
                data["totalSensors"] = (counts.values.reduce(0, +))
                data["note"] = "On modern T2-era Intel Macs, also check `macli monitor --metrics smc_temp` for additional PMU tdev/tdie sensors exposed via HID bridge."
            } else {
                data["error"] = "Cannot open Intel SMC (not an Intel Mac?)"
            }

            outputJson(data: data)
        }
    )
}
