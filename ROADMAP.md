# Roadmap

This is the high-level plan for `macli`. For already-released changes see [`changelog/`](changelog/).

Guiding principle: **macli only does what shell / Python cannot do easily** — private frameworks, HID/IOKit, reverse-engineered protocols, and high-frequency polling.

---

## Shipped

- [x] SMC sensor snapshot (`macli smc`) — temperature, voltage, current on Apple Silicon
- [x] Legacy Intel SMC (`macli smc86`) — `AppleSMC.kext` private selector communication
- [x] Streaming monitor (`macli monitor`) — TSV output for shell pipelines
- [x] EventKit access (`macli cal`, `macli event`, `macli reminder`, `macli aka`)
- [x] User notifications (`macli notify`) and text-to-speech (`macli speak`)
- [x] Multi-formula Homebrew tap [`ljh-sh/cli`](https://github.com/ljh-sh/homebrew-cli)
- [x] Signed releases (cosign keyless `.sigstore.json` bundles)
- [x] Battery & power snapshot (`macli battery`) with JSON/TSV/plist output
- [x] Battery power metrics in `macli monitor`
- [x] Basic NVMe drive info (`macli ssd`) via `system_profiler`
- [x] SSD scope documented; detailed SMART left to `smartctl`

---

## v0.4.0 — Display & GPU primitives

Goal: expose stable display/GPU metadata and experimental utilization sampling.

- [x] `macli display brightness` read current brightness
- [x] Optional brightness set via `DisplayServicesSetBrightness` behind `--set`
- [x] `macli gpu info` — core count, device name, unified memory size
- [x] `macli monitor --metrics gpu_metrics` experimental GPU utilization sampling
  - reads `AGXAccelerator` `PerformanceStatistics` without root
  - clearly marked experimental because counter key names vary across Apple Silicon generations
- [ ] CPU/GPU frequency sampling via `powermetrics` / IOKit
  - requires root
  - deferred until a stable IOKit key mapping is identified
- [ ] Close or split the AXUIElement (window / app automation) feasibility discussion

Success criteria:
- Read paths work without root.
- Write paths require an adjustable display and print a clear error otherwise.

---

## Infrastructure & hardening

These run in parallel with feature milestones.

- [ ] Release workflow auto-updates `Formula/macli.rb` in [`ljh-sh/homebrew-cli`](https://github.com/ljh-sh/homebrew-cli) on every new tag
- [x] Unit tests for battery IORegistry parsing (`batteryTests` with mocked data)
- [ ] Unit tests for `smc` key parsing, EventKit output formatting, and CLI argument parsing
- [ ] OpenSSF Scorecard >= 8.5
  - keep `Signed-Releases`, `CI-Tests`, `Code-Review`, and dependency-update checks green
  - add fuzzing or property-based tests only if a clear fragile parser justifies the cost
- [x] Reproducible build verification in CI for every release
- [ ] Add `roff` to `ljh-sh/cli` once `roff` cuts its first tagged release

---

## Not planned

These are intentionally out of scope for `macli`:

- **GUI** — macli is CLI-only by design.
- **Linux / Windows** — macOS-only by design.
- **Built-in aggregation or alerting** — leave that to `awk` / `jq` / `python` downstream.
- **Public-stable APIs that are only ugly in Python** — if Apple documents it (e.g. Metal device caps) and it does not change across OS releases, the win for a native CLI is too small.

---

## How decisions are made

New candidates are evaluated with two questions:

1. Is the API truly fragile or permission-sensitive enough that shell / Python is unreliable?
2. Does centralizing it in `macli` reduce duplicated patch work across OS upgrades?

If both are yes, it belongs in a future milestone. If only the second is no, it stays in shell-land.
