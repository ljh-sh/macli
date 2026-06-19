import Foundation

enum GpuCmd: Cmd {
    static let meta = CmdMeta(
        name: "gpu",
        desc: "GPU information",
        subcmds: [
            "info": GpuInfoCmd.self,
        ]
    )
}

enum GpuInfoCmd: Cmd {
    static let meta = CmdMeta(
        name: "info",
        desc: "GPU name, unified memory, and core count",
        opts: [
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
            OptMeta(name: "--tsv", type: Bool.self, desc: "Output TSV"),
        ],
        run: { p in
            let data = GpuCtrl().getGpuInfo()

            guard (data["ok"] as? Bool) == true else {
                outputJson(data: data.merging(["ok": false], uniquingKeysWith: { _, new in new }))
                return
            }

            var output = data
            output["ok"] = true

            if p.opt("--tsv") as Bool? == true {
                printTsv(output)
            } else {
                outputJson(data: output)
            }
        }
    )
}

private func printTsv(_ data: [String: Any]) {
    print("key\tvalue")
    if let name = data["name"] as? String { print("name\t\(name)") }
    if let unified = data["hasUnifiedMemory"] as? Bool { print("hasUnifiedMemory\t\(unified)") }
    if let mem = data["recommendedMaxWorkingSetSizeBytes"] as? UInt64 { print("recommendedMaxWorkingSetSizeBytes\t\(mem)") }
    if let cores = data["coreCount"] as? Int { print("coreCount\t\(cores)") }
}
