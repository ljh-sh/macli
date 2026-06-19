import Foundation

enum DisplayCmd: Cmd {
    static let meta = CmdMeta(
        name: "display",
        desc: "Display brightness and info via DisplayServices",
        subcmds: [
            "list": DisplayListCmd.self,
            "brightness": DisplayBrightnessCmd.self,
        ]
    )
}

enum DisplayListCmd: Cmd {
    static let meta = CmdMeta(
        name: "list",
        desc: "List online displays",
        opts: [
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
            OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV"),
        ],
        run: { p in
            let data = DisplayCtrl().getDisplays()
            if p.opt("--tsv") as Bool? == true {
                printDisplayListTsv(data)
            } else {
                outputJson(data: data)
            }
        }
    )
}

enum DisplayBrightnessCmd: Cmd {
    static let meta = CmdMeta(
        name: "brightness",
        desc: "Read or set display brightness (0.0–1.0)",
        opts: [
            OptMeta(name: "--set", type: Double.self, desc: "Set brightness level"),
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
            OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV"),
        ],
        run: { p in
            let ctrl = DisplayCtrl()
            if let value = p.opt("--set") as Double? {
                let result = ctrl.setBrightness(Float(value))
                if p.opt("--tsv") as Bool? == true {
                    printBrightnessSetTsv(result)
                } else {
                    outputJson(data: result)
                }
                return
            }

            let data = ctrl.getDisplays()
            if p.opt("--tsv") as Bool? == true {
                printBrightnessTsv(data)
            } else {
                outputJson(data: data)
            }
        }
    )
}

private func printDisplayListTsv(_ data: [String: Any]) {
    print("id\tmain\tbuiltIn\tactive\tbrightness")
    guard let displays = data["displays"] as? [[String: Any]] else { return }
    for d in displays {
        let id = d["id"] as? UInt32 ?? 0
        let main = d["main"] as? Bool ?? false
        let builtIn = d["builtIn"] as? Bool ?? false
        let active = d["active"] as? Bool ?? false
        let brightness = d["brightness"] as? Float
        let brightnessStr = brightness.map { String($0) } ?? ""
        print("0x\(String(id, radix: 16))\t\(main)\t\(builtIn)\t\(active)\t\(brightnessStr)")
    }
}

private func printBrightnessTsv(_ data: [String: Any]) {
    print("id\tbrightness")
    guard let displays = data["displays"] as? [[String: Any]] else { return }
    for d in displays {
        let id = d["id"] as? UInt32 ?? 0
        let brightness = d["brightness"] as? Float
        let brightnessStr = brightness.map { String($0) } ?? ""
        print("0x\(String(id, radix: 16))\t\(brightnessStr)")
    }
}

private func printBrightnessSetTsv(_ data: [String: Any]) {
    print("key\tvalue")
    if let ok = data["ok"] as? Bool { print("ok\t\(ok)") }
    if let id = data["displayID"] as? UInt32 { print("displayID\t0x\(String(id, radix: 16))") }
    if let brightness = data["brightness"] as? Float { print("brightness\t\(brightness)") }
    if let error = data["error"] as? String { print("error\t\(error)") }
}
