import Foundation

enum MonitorCmd: Cmd {
    static let meta = CmdMeta(
        name: "monitor",
        desc: "Streaming TSV monitor. Single process, all metric sources. Downstream awk-friendly.",
        opts: [
            OptMeta(name: "--interval", type: Double.self, desc: "Seconds between samples (default 1.0, supports decimal)"),
            OptMeta(name: "--metrics", type: String.self, desc: "Comma-separated metric sources (default: all)"),
            OptMeta(name: "--count", type: Int.self, desc: "Number of samples before exit (default: infinite)"),
        ],
        run: { p in
            let interval: Double = p.opt("--interval") ?? 1.0
            let metricsStr: String? = p.opt("--metrics")
            let maxCount: Int? = p.opt("--count")

            // Registry: all available metric sources
            let registry: [String: MetricSource] = [
                "smc_temp": SmcTempSource(),
                "smc_volt": SmcVoltSource(),
                "smc_curr": SmcCurrSource(),
            ]

            // Select sources
            let selected: [(String, MetricSource)]
            if let s = metricsStr {
                let names = s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var found: [(String, MetricSource)] = []
                var missing: [String] = []
                for n in names {
                    if let src = registry[n] {
                        found.append((n, src))
                    } else {
                        missing.append(n)
                    }
                }
                if !missing.isEmpty {
                    cmdError("unknown metrics: \(missing.joined(separator: ",")). available: \(registry.keys.sorted().joined(separator: ", "))")
                }
                selected = found
            } else {
                selected = registry.keys.sorted().map { ($0, registry[$0]!) }
            }

            if selected.isEmpty {
                cmdError("no metric sources selected")
            }

            // Pre-sample to establish column layout (sensor names are stable across samples for HID)
            let layout: [(prefix: String, columns: [(name: String, unit: String)])] = selected.map { (key, src) in
                let s = src.sample()
                return (key, s.map { (sanitizeMetricName($0.name), $0.unit) })
            }

            // Print header
            var header = "ts"
            for entry in layout {
                for col in entry.columns {
                    header += "\t\(entry.prefix)_\(col.name)"
                }
            }
            print(header)

            // SIGINT handler: flush and exit cleanly
            signal(SIGINT) { _ in
                exit(0)
            }
            signal(SIGTERM) { _ in
                exit(0)
            }

            // Stream loop
            var count = 0
            while maxCount == nil || count < maxCount! {
                let ts = String(format: "%.3f", Date().timeIntervalSince1970)
                var line = ts

                for (i, (_, src)) in selected.enumerated() {
                    let samples = src.sample()
                    let expected = layout[i].columns

                    // Align by position: HID sensor arrays are positionally stable across
                    // samples on the same machine. Names are documentation; indices are the
                    // contract. Only fall back to name matching if the sample count diverges.
                    if samples.count == expected.count {
                        for s in samples {
                            if s.value.isNaN {
                                line += "\t"
                            } else {
                                line += "\t\(s.value)"
                            }
                        }
                    } else {
                        var byName: [String: Double] = [:]
                        for s in samples {
                            byName[sanitizeMetricName(s.name)] = s.value
                        }
                        for col in expected {
                            let v = byName[col.name] ?? Double.nan
                            if v.isNaN {
                                line += "\t"
                            } else {
                                line += "\t\(v)"
                            }
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
            TldrItem(desc: "Stream specific metrics at 2Hz", cmd: "macli monitor --interval 0.5 --metrics smc_temp,smc_curr"),
            TldrItem(desc: "Take 10 samples then exit", cmd: "macli monitor --count 10"),
            TldrItem(desc: "Downstream processing with awk", cmd: "macli monitor | awk -F'\\t' 'NR>1 {sum+=$2; n++} END {print sum/n}'"),
        ]
    }
}
