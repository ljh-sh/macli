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

---

## v0.2.0 — Battery & power

Goal: expose the full `AppleSmartBattery` IORegistry snapshot in a script-friendly form.

- [ ] `macli battery` snapshot
  - cycle count, design capacity, current maximum capacity
  - health percentage, cell voltages, design / current Wh
  - AC charging state, input power (watts), manufacture date
- [ ] Output modes: `--json`, `--tsv`, and `--plist`
- [ ] Add battery power draw / charge rate to `macli monitor` stream
- [ ] CI tests using mocked IORegistry data so GitHub runners can validate parsing
- [ ] README examples for battery-health scripting

Success criteria:
- `macli battery` runs in < 50 ms on a MacBook.
- Output schema is stable and documented in `--help`.

---

## v0.3.0 — SSD health

Goal: read NVMe SMART data without requiring `smartmontools`.

- [ ] `macli ssd` snapshot
  - TBW (total bytes written), wear leveling count, available spare
  - media errors, temperature, power cycles
- [ ] Per-disk selection: `macli ssd --disk disk0`
- [ ] Threshold exit codes: `--warn-spare`, `--warn-wear`
- [ ] Document Apple Silicon SSD compatibility matrix

Success criteria:
- Works on Apple Silicon internal SSD and external Thunderbolt NVMe.
- Falls back gracefully when SMART is unavailable.

---

## v0.4.0 — Display & GPU primitives

Goal: expose stable display/GPU metadata and experimental frequency sampling.

- [ ] `macli display brightness` read current brightness
- [ ] Optional brightness set via `CoreDisplay_Display_SetUserBrightness` behind `--set`
- [ ] `macli gpu info` — core count, device name, unified memory size
- [ ] `macli monitor --experimental` GPU/CPU frequency sampling
  - requires root for `powermetrics` / IOKit path
  - clearly marked experimental because IOKit key names and units change between Apple Silicon generations
- [ ] Close or split the AXUIElement (window / app automation) feasibility discussion

Success criteria:
- Read paths work without root.
- Write / frequency paths print a clear root-required message instead of crashing.

---

## Infrastructure & hardening

These run in parallel with feature milestones.

- [ ] Release workflow auto-updates `Formula/macli.rb` in [`ljh-sh/homebrew-cli`](https://github.com/ljh-sh/homebrew-cli) on every new tag
- [ ] Unit tests for `smc` key parsing, EventKit output formatting, and CLI argument parsing
- [ ] OpenSSF Scorecard >= 8.5
  - keep `Signed-Releases`, `CI-Tests`, `Code-Review`, and dependency-update checks green
  - add fuzzing or property-based tests only if a clear fragile parser justifies the cost
- [ ] Reproducible build verification in CI for every release
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
