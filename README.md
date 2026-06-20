# macli

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/ljh-sh/macli/badge)](https://scorecard.dev/)
[![CI](https://github.com/ljh-sh/macli/actions/workflows/ci.yml/badge.svg)](https://github.com/ljh-sh/macli/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/Docs-website-blue.svg)](https://ljh-sh.github.io/macli)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE.txt)

> Minimal context with maximum flexibility — macOS system tools for AI agents. Native Apple frameworks. AI-friendly JSON/TSV output.

**macli** turns macOS system internals into a clean CLI. SMC sensors, streaming monitor, calendar/reminders — all callable from shell pipes or LLM agents, all JSON/TSV. One ~400 KB Swift binary. No Python runtime, no osascript overhead, no GUI.

Use it when you (or your AI agent) need to ask macOS something that `system_profiler` / `ioreg` / `osascript` either can't answer or answer badly: *CPU die temperature right now*, *stream 1 Hz sensor readings into awk*, *today's calendar as JSON*.

## Governance

macli is maintained by the core team listed in [CODEOWNERS](./CODEOWNERS).
All changes to `main` require a pull request and approval from a code owner.
See [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

Mirrors: [github.com/ljh-sh/macli](https://github.com/ljh-sh/macli) · [codeberg.org/ljh-sh/macli](https://codeberg.org/ljh-sh/macli)

Docs: [ljh-sh.github.io/macli](https://ljh-sh.github.io/macli)

## For AI agents

Minimal context with maximum flexibility — paste this one-line prompt into Claude Code, Cursor, or any agent's system prompt:

```md
Use `macli` for macOS system state (sensors / calendar / reminders). Install if missing: `brew install ljh-sh/cli/macli`. JSON output, check `ok`. Run `macli --help` for subcommands.
```

## Install

### Homebrew (recommended)

```sh
brew install ljh-sh/cli/macli
```

Or tap once, then use the short name:

```sh
brew tap ljh-sh/cli
brew install macli
```

### Direct binary

```sh
curl -L https://github.com/ljh-sh/macli/releases/latest/download/macli-darwin-universal.tar.xz | tar xJ -
sudo mv bin/macli /usr/local/bin/
```

The `universal` tarball is a fat Mach-O (arm64 + x86_64) — works on Apple Silicon and Intel Macs.

### eget

Via [x-cmd eget](https://x-cmd.com/mod/eget):

```sh
x eget use ljh-sh/macli              # install latest to ~/.local/bin
x eget use --tag v0.4.2 ljh-sh/macli # install a specific release
```

### npm

```sh
npm install -g @ljh-sh/macli
```

The npm package downloads the universal macOS binary from the GitHub release during install.

### Build from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/macli
cd macli
swift build -c release
```

## At a glance

```sh
macli smc temp                              # CPU/GPU temps as JSON
macli gpu info                              # GPU name, cores, unified memory
macli display brightness                    # built-in display brightness
macli monitor --count 10 --interval 1       # stream 10 samples to awk
macli cal ls                                # list calendars as JSON
```

Output schema: `{"ok": true, ...}` on success, `{"ok": false, "error": "...", "hint": "..."}` on failure. Never silent.

---

## Roadmap

- [x] SMC sensor snapshot, streaming monitor, EventKit
- [x] Battery health (`macli battery`)
- [x] SSD health (`macli ssd`)
- [x] Display brightness & GPU info (`macli display`, `macli gpu`)

See [ROADMAP.md](ROADMAP.md) for details.

---

## SMC sensors

The headline use case. `macli smc` reads hardware sensors that macOS exposes only through private frameworks.

```sh
macli smc temp            # → JSON, all temperature sensors
macli smc temp --tsv      # → TSV for awk
macli smc volt            # → PMU voltage rails
macli smc curr            # → PMU current rails
macli smc all             # → everything
```

Sample output:

```json
{
  "ok": true,
  "source": "HID",
  "sensors": [{"name": "PMU tdie1", "value": 57.5, "unit": "°C"}],
  "count": 45
}
```

### Battery & SSD health

macli also exposes battery and SSD info as standalone commands, both JSON/TSV friendly:

```sh
macli battery             # cycle count, capacity, health %, temperature
macli battery --tsv       # tab-separated for spreadsheets/awk
macli battery --plist     # full raw AppleSmartBattery IORegistry snapshot
macli ssd                 # NVMe model, serial, SMART status, TRIM, volumes
```

`macli battery` reads from IOKit (`AppleSmartBattery`).

`macli ssd` parses `system_profiler SPNVMeDataType`. It returns model, serial,
capacity, SMART status, TRIM support and volumes. It does **not** parse detailed
SMART log pages because Apple does not expose them through a public API. For
wear-level data (TBW, percentage used, media errors, etc.) use `smartctl`:

```sh
brew install smartmontools
smartctl -a disk0
```

SSD compatibility:

| Platform | Basic info (`macli ssd`) | Detailed SMART |
|---|---|---|
| Apple Silicon internal SSD | ✅ | Use `smartctl` |
| External Thunderbolt NVMe | ✅ | Use `smartctl` |
| USB/SATA adapters | May appear as storage, not NVMe | Use `smartctl` |

Scripting examples:

```sh
# Alert when battery health drops below 80%
macli battery | jq -e '.healthPercent < 80' && echo "consider replacement"

# Log cycle count and temperature to a file
macli battery --tsv | awk -F'\t' '/^cycleCount|^temperature/{print strftime("%Y-%m-%dT%H:%M:%S"), $1, $2}' >> battery.log

# Monitor system + battery power draw in real time
macli monitor --metrics battery_power --interval 1
```

### Display & GPU

`macli display` reads and sets display brightness through the private
`DisplayServices` framework. `macli gpu` reports the active GPU via `Metal` and
reads core count / performance counters from `AGXAccelerator` in `IOKit`.

```sh
macli display list                      # all online displays + brightness
macli display brightness                # current brightness (0.0–1.0)
macli display brightness --set 0.5      # set built-in display brightness
macli gpu info                          # name, unified memory, core count
macli gpu info --tsv                    # tab-separated output
```

`monitor` can also stream GPU utilization (experimental, Apple Silicon only):

```sh
macli monitor --metrics gpu_metrics --interval 1
```

### Design: agent-oriented

macli follows the x-cmd agent-tool design principle: **minimal context with maximum flexibility**. It stays **dumb** — it does **not** compute thermal indexes, aggregate, render charts, or decide what's "hot". It returns raw sensor values, full stop. Decisions belong to the caller:

```sh
macli smc temp --tsv | awk -F'\t' '$2 > 80 {print $1, "OVERHEAT"}'
macli smc temp --tsv | sort -t$'\t' -k2 -n | tail -5    # 5 hottest sensors
```

This keeps `macli --help` short (saves tokens when an LLM loads it as context). The CLI is the API; the shell is the glue.

### `smc86` — Intel legacy, sunset track

`smc86` is the Intel-Mac counterpart, same interface. Returns empty on Apple Silicon (Intel SMC key space was cleared). Will be removed when Intel Macs go EOL.

---

## Streaming monitor

`monitor` samples sensor sources on an interval and streams TSV — one row per sample. Single process, no subprocess fork per poll, no Python interpreter per tick. Designed as a long-running pipe stage for `awk`.

```sh
macli monitor --interval 1 --metrics smc_temp,smc_curr
macli monitor --count 10 --interval 0.5 --metrics smc_temp \
  | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print "avg:", sum/n}'
macli monitor --metrics gpu_metrics --interval 1   # GPU utilization (experimental)
```

Flags:

- `--interval N` — seconds between samples (supports decimals, default 1.0)
- `--metrics list` — comma-separated sources (default: all). Sources: `smc_temp`, `smc_volt`, `smc_curr`, `battery_power`, `gpu_metrics`
- `--count N` — exit after N samples (default: infinite, Ctrl-C to stop)

The header row locks column order; subsequent rows match positionally. `awk -F'\t'` is the intended downstream.

Why this matters: a shell loop (`while; do macli smc temp; sleep 1; done`) costs ~50ms of binary startup per iteration. `monitor` pays that once and streams samples at sub-millisecond marginal cost.

---

## EventKit — calendar / event / reminder

`EventKit.framework` is Apple's native API for Calendar and Reminders. macli wraps it for the shell — JSON output, no AppleScript involved.

```sh
macli cal ls                                # list calendars
macli event ls --calendar Work --today      # today's events
macli reminder add --list Shopping "Buy milk"
macli aka set work <calendar-id>            # alias calendar IDs for stable refs
```

Use cases: dashboards, CI notifiers ("next event in 5 min"), reminder batching, automation hooks that need stable calendar references (`aka`).

---

## Output conventions

- **Snapshot commands**: JSON with `{"ok": bool, ...}` (default). `--tsv` for awk-friendly.
- **Streaming commands** (`monitor`): TSV only, header on first line.
- **Errors**: `{"ok": false, "error": "...", "hint": "..."}` — never silent.

---

## FAQ

The full FAQ lives on the docs site: [ljh-sh.github.io/macli/faq](https://ljh-sh.github.io/macli/faq).  
Source: [`docs/faq.md`](docs/faq.md).

## FAQ about Installation & permissions

### ❓ "macli cannot be opened because the developer cannot be verified"

macli ships with ad-hoc signature (no Apple Developer ID). For direct-download installs, strip the quarantine attribute:
```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```
The Homebrew formula does this automatically via `post_install`.

### ❓ `brew install macli` says "trust" or refuses to load the formula

Homebrew 6 added a trust step for third-party taps. Run `brew trust ljh-sh/cli` once, then `brew install ljh-sh/cli/macli`. This is a security feature, not a bug.

### ❓ First `macli cal ls` / `event ls` / `reminder` call hangs for seconds

macOS TCC is prompting for Calendar/Reminders access. Click the system dialog to grant. Subsequent calls are instant. If you missed the prompt, go to System Settings → Privacy & Security → Calendars (or Reminders) and enable the terminal you're running macli from.

## FAQ about SMC — what it is, why macli exists

### ❓ What is SMC?

The **System Management Controller (SMC)** is an Apple controller embedded in every Mac. It monitors and reports CPU / GPU / SoC die temperatures, PMU voltage rails, PMU current rails, fan speeds (Intel Macs), and battery state.

On Intel Macs, SMC is queried through `IOKit.framework`'s private AppleSMC API using 4-character keys (`TCXC`, `TG0P`, …). On Apple Silicon (M1–M4), the same data moved to a HID sensor hub — the keys are entirely different (`PMU tdie1`, `PMU tdie2`, …) and undocumented.

References — the projects that mapped this out:
- [dkorunic/iSMC](https://github.com/dkorunic/iSMC) — Go CLI, comprehensive SMC key catalog (Intel + Apple Silicon)
- [beltex/SMCKit](https://github.com/beltex/SMCKit) — Swift SMC library, the classic Intel-era reference
- [freedomtan/sensors](https://github.com/freedomtan/sensors) — early Apple Silicon IOKit exploration

### ❓ Why not Python / PyObjC?

Reading one sensor takes ~30 lines of C: open the `AppleSMC` / `AppleHID` IOService, serialize the key, call `IOConnectCallScalarMethod`, unpack the returned struct. The keys are private, the structs are private, the call convention changed between Intel and Apple Silicon.

PyObjC can call public frameworks, but the SMC key space is **private**. Reaching it from Python means ctypes-level struct packing that breaks with every macOS release. There is no `pip install` path that keeps up with Apple Silicon's new key namespace.

### ❓ `macli smc86 ...` returns empty results on Apple Silicon

Expected. `smc86` queries the Intel-Mac SMC key space, which Apple cleared on Apple Silicon. Use `macli smc` (not `smc86`) on M-series Macs.

### ❓ How is macli different from iStats / smcFanControl / stats / iSMC / SMCKit?

- [iStats](https://github.com/Chris911/iStats) — Ruby gem, Intel-only, last released 2018. GUI-leaning.
- [smcFanControl](https://github.com/hholtmann/smcFanControl) — macOS app for setting minimum fan speed. GUI.
- [stats](https://github.com/exelban/stats) — macOS menu-bar dashboard. GUI.
- [iSMC](https://github.com/dkorunic/iSMC) — Go CLI. Closest peer, but Go runtime adds ~5 MB to the binary.
- [SMCKit](https://github.com/beltex/SMCKit) — Swift library, Intel-only. No CLI streaming, no EventKit.
- **macli** — Swift CLI built for shell pipes and LLM agents. JSON/TSV only, no GUI, no Ruby/Go runtime, Apple Silicon first-class. Smallest binary in the list (~400 KB stripped).

## FAQ about EventKit internals

### ❓ Why is `macli cal ls` faster than `osascript`?

osascript routes through AppleScript → Calendar.app RPC channel → permission prompts. Every cold start loads the AppleScript component. macli links `EventKit.framework` directly and requests permission once via the standard TCC prompt; subsequent calls are in-process.

### ❓ Why JSON instead of AppleScript list syntax?

AppleScript returns human-formatted strings like `{calendar "Work", calendar "Home"}`. Parsing that requires regex on localized strings. JSON is parseable by `jq`, python, awk, every LLM tool-use interface, with stable field names regardless of system language.

### ❓ Does macli modify my calendar data?

Read commands (`cal ls`, `event ls`) never touch state. Write commands (`cal add`, `event add`, `reminder add`) only run when you invoke them explicitly, with the exact arguments you pass. macli never syncs, never deletes, never auto-modifies.

## FAQ about Compatibility

### ❓ Linux / Windows?

No. macli wraps Apple-private frameworks (IOKit, HID, EventKit) that exist only on macOS.

### ❓ Do I need `sudo`?

No. All subcommands run as the invoking user. Sensor reads go through user-space IOKit / HID APIs.

### ❓ Apple Silicon vs Intel?

Both supported via a single universal binary. On Apple Silicon use `macli smc`; on Intel use `macli smc86`. The binaries are identical; the subcommand selects the sensor path.

## FAQ about Internals

### ❓ Binary size

~400 KB per arch (arm64 / x86_64), ~830 KB universal (fat Mach-O), ~110 KB arm64 tar.xz. Single static-ish binary — no Python runtime, no PyObjC bridge, no ctypes layer.

### ❓ Code signature

Ad-hoc. Not Apple Developer ID (would require $99/year and notarization for marginal benefit). The Homebrew formula strips `com.apple.quarantine` automatically. Manual installs need one `xattr -dr`.

### ❓ Is the build reproducible?

Mostly yes.

- Reproducibility depends on pinning Xcode / LLVM versions.
- Build hardening — `SOURCE_DATE_EPOCH`, `ZERO_AR_DATE`, deterministic mtimes, RPATH removal — lives in `.x-cmd/release.common.sh`.

### ❓ Why was speech recognition (`macli speech recognize`) removed?

Short version: macOS won't let a bare CLI use speech recognition.

- `SFSpeechRecognizer` needs an `Info.plist` with `NSSpeechRecognitionUsageDescription`.
- SwiftPM CLI binaries don't have one, so TCC denies access and the process crashes.
- Fixing it means bundling macli as a `.app`, which isn't worth the pipeline complexity.
- Use [hear](https://github.com/sveinbjornt/hear) instead — it's signed, notarized, and does exactly this job.

### ❓ Why no aggregation / alerting built-in?

Aggregation (avg, max, rolling window) and alerting (threshold → notify) belong in awk/jq/python where you control the semantics. Embedding them in macli would mean every new stat needs a new flag, and the `--help` would balloon past what an LLM can cheaply load as context. See "Design: agent-oriented" above.

---

## Changelog

See [`changelog/`](changelog/) for versioned release notes, starting with [`v0.0.0.md`](changelog/v0.0.0.md).

---

## Acknowledgments

- Built with [Swift](https://www.swift.org/) and Apple native frameworks.
- Release signing uses [Sigstore](https://www.sigstore.dev/) and [cosign](https://github.com/sigstore/cosign).
- SLSA provenance generated by the [OpenSSF slsa-github-generator](https://github.com/slsa-framework/slsa-github-generator).

## Reproducible builds

macli releases are built deterministically in GitHub Actions. The build pins
`SOURCE_DATE_EPOCH`, disables variable timestamps, and produces bit-for-bit
reproducible tarballs on Apple Silicon. See `.x-cmd/release.common.sh` for the
exact environment and `BUILD_INFO.txt` in each release for build parameters.

## Support

- Read the [docs](https://ljh-sh.github.io/macli).
- Open a [discussion](https://github.com/ljh-sh/macli/discussions) for questions.
- Open an [issue](https://github.com/ljh-sh/macli/issues) for bugs or feature requests.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](./CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.

## License

Apache 2.0 — see [LICENSE.txt](LICENSE.txt).


## Verifying releases

Release tarballs are signed with [Sigstore/cosign](https://www.sigstore.dev/). Each
release includes `.sigstore.json` bundles for the tarballs, `SHA256SUMS`, and
`BUILD_INFO.txt`. Verify a tarball with:

```sh
cosign verify-blob \
  --bundle macli-darwin-universal.tar.xz.sigstore.json \
  --certificate-identity-regexp '^https://github.com/ljh-sh/macli/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  macli-darwin-universal.tar.xz
```

The npm package `@ljh-sh/macli` is published from GitHub Actions. You can verify
its provenance with:

```sh
npm install -g @ljh-sh/macli
npm audit signatures
```
