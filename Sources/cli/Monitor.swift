import Foundation

private var gMonitorCancelled: Int32 = 0

private struct ColumnRef: Hashable {
    let sourceKey: String
    let name: String
    let unit: String
    let fullName: String
}

enum MonitorCmd: Cmd {
    static let meta = CmdMeta(
        name: "monitor",
        desc: "Streaming TSV monitor. Single process, all metric sources. Downstream awk-friendly.",
        opts: [
            OptMeta(name: "--interval", type: Double.self, desc: "Seconds between samples (default 1.0, supports decimal)"),
            OptMeta(name: "--metric", alias: "--metrics", type: String.self, desc: "Comma-separated source or column-prefix filters (default: all). Sources: smc_temp, smc_volt, smc_curr, battery_power, gpu_metrics"),
            OptMeta(name: "--count", type: Int.self, desc: "Number of samples before exit (default: infinite)"),
        ],
        run: { p in
            let interval: Double = p.opt("--interval") ?? 1.0
            let metricStr: String? = p.opt("--metric", "--metrics")
            let maxCount: Int? = p.opt("--count")

            guard interval > 0 else { cmdError("--interval must be > 0") }
            if let mc = maxCount, mc <= 0 { cmdError("--count must be > 0") }

            // Registry: all available metric sources
            let registry: [String: MetricSource] = [
                "smc_temp": SmcTempSource(),
                "smc_volt": SmcVoltSource(),
                "smc_curr": SmcCurrSource(),
                "battery_power": BatteryPowerSource(),
                "gpu_metrics": GpuMetricsSource(),
            ]

            // Enumerate every available column once to build the prefix-filter universe.
            var allColumns: [ColumnRef] = []
            for (key, src) in registry {
                for s in src.sample() {
                    let n = sanitizeMetricName(s.name)
                    allColumns.append(ColumnRef(
                        sourceKey: key,
                        name: n,
                        unit: s.unit,
                        fullName: "\(key)_\(n)"
                    ))
                }
            }

            // Apply filters. A filter can be an exact source key or a prefix of the full
            // column name (e.g. "smc_temp" selects all temperature columns; "smc_temp_cpu"
            // selects only the CPU temperature subset).
            let selectedColumns: [ColumnRef]
            if let s = metricStr {
                let filters = s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var matched = Set<ColumnRef>()
                var unmatched: [String] = []
                for f in filters {
                    let hits = allColumns.filter { $0.sourceKey == f || $0.fullName.hasPrefix(f) }
                    if hits.isEmpty {
                        unmatched.append(f)
                    } else {
                        matched.formUnion(hits)
                    }
                }
                if !unmatched.isEmpty {
                    cmdError("unknown metric filters: \(unmatched.joined(separator: ", ")). available sources: \(registry.keys.sorted().joined(separator: ", "))")
                }
                selectedColumns = Array(matched)
            } else {
                selectedColumns = allColumns
            }

            if selectedColumns.isEmpty {
                cmdError("no metric columns selected")
            }

            // Preserve deterministic order: source keys sorted, columns in discovery order.
            let selectedSources = registry.keys.sorted().compactMap { key -> (String, MetricSource, [(name: String, unit: String)])? in
                let cols = selectedColumns
                    .filter { $0.sourceKey == key }
                    .map { (name: $0.name, unit: $0.unit) }
                guard let src = registry[key], !cols.isEmpty else { return nil }
                return (key, src, cols)
            }

            // Print header
            var header = "ts"
            for (key, _, cols) in selectedSources {
                for col in cols {
                    header += "\t\(key)_\(col.name)"
                }
            }
            print(header)

            // SIGINT/SIGTERM: set a flag so the current sample is flushed before exit.
            gMonitorCancelled = 0
            signal(SIGINT) { _ in gMonitorCancelled = 1 }
            signal(SIGTERM) { _ in gMonitorCancelled = 1 }

            // Stream loop
            var count = 0
            while (maxCount == nil || count < maxCount!) && gMonitorCancelled == 0 {
                let ts = String(format: "%.3f", Date().timeIntervalSince1970)
                var line = ts

                for (_, src, cols) in selectedSources {
                    let samples = src.sample()
                    var byName: [String: Double] = [:]
                    for s in samples {
                        byName[sanitizeMetricName(s.name)] = s.value
                    }
                    for col in cols {
                        let v = byName[col.name] ?? Double.nan
                        if v.isNaN {
                            line += "\t"
                        } else {
                            line += "\t\(v)"
                        }
                    }
                }

                print(line)
                fflush(stdout)

                count += 1
                if let mc = maxCount, count >= mc { break }
                Thread.sleep(forTimeInterval: interval)
            }
        }
    )

    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "Stream all metrics at 1Hz (Ctrl+C to stop)", cmd: "macli monitor"),
            TldrItem(desc: "Stream specific metrics at 2Hz", cmd: "macli monitor --interval 0.5 --metric smc_temp,smc_curr"),
            TldrItem(desc: "Stream battery power draw", cmd: "macli monitor --metric battery_power"),
            TldrItem(desc: "Stream GPU utilization (experimental)", cmd: "macli monitor --metric gpu_metrics"),
            TldrItem(desc: "Take 10 samples then exit", cmd: "macli monitor --count 10"),
            TldrItem(desc: "Downstream processing with awk", cmd: "macli monitor | awk -F'\\t' 'NR>1 {sum+=$2; n++} END {print sum/n}'"),
        ]
    }
}
