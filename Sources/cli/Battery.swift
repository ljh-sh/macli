import Foundation

enum BatteryCmd: Cmd {
    static let meta = CmdMeta(
        name: "battery",
        desc: "Battery snapshot via IOKit",
        opts: [
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
            OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV"),
            OptMeta(name: "--plist", type: Bool.self, desc: "Output raw IORegistry snapshot as XML plist"),
        ],
        run: { p in
            let ctrl = BatteryCtrl()

            if p.opt("--plist") as Bool? == true {
                guard let snapshot = ctrl.getSnapshot() else {
                    outputJson(data: ["ok": false, "error": "No battery found"])
                    return
                }
                guard let data = XCMD.plist.data(snapshot) else {
                    outputJson(data: ["ok": false, "error": "Plist serialization failed"])
                    return
                }
                FileHandle.standardOutput.write(data)
                return
            }

            var data = ctrl.getBattery()
            data["ok"] = true

            if p.opt("--tsv") as Bool? == true {
                printBatteryTsv(data)
            } else {
                outputJson(data: data)
            }
        }
    )
}

private func printBatteryTsv(_ data: [String: Any]) {
    print("name\tvalue\tunit")
    for key in data.keys.sorted() {
        if key == "ok" || key == "source" || key == "present" { continue }
        let value = data[key]
        if let num = value as? NSNumber {
            print("\(key)\t\(num)\t")
        } else if let str = value as? String {
            print("\(key)\t\(str)\t")
        } else if let bool = value as? Bool {
            print("\(key)\t\(bool)\t")
        } else if let arr = value as? [NSNumber] {
            for (idx, num) in arr.enumerated() {
                print("\(key)_\(idx)\t\(num)\t")
            }
        } else if let dict = value as? [String: Any] {
            for (subKey, subValue) in dict.sorted(by: { $0.key < $1.key }) {
                if let num = subValue as? NSNumber {
                    print("\(key).\(subKey)\t\(num)\t")
                } else if let str = subValue as? String {
                    print("\(key).\(subKey)\t\(str)\t")
                }
            }
        }
    }
}
