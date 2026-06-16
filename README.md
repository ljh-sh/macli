# macli

> macOS system tools for AI agents. Native Apple frameworks. AI-friendly JSON/TSV output.

**macli** is a small Swift CLI that exposes macOS system state — SMC sensors, streaming monitor, calendar/reminders, speech — via the same native Apple frameworks your GUI apps use. Single binary, JSON/TSV output, designed to be driven by LLM agents and shell scripts alike.

Mirrors: [github.com/ljh-sh/macli](https://github.com/ljh-sh/macli) · [codeberg.org/ljh-sh/macli](https://codeberg.org/ljh-sh/macli)

## For AI agents

One-line prompt — paste into Claude Code, Cursor, or any agent's system prompt:

```md
Install `macli` if missing: `brew install ljh-sh/macli/macli`. Use it for macOS system state (sensors / calendar / speech / notifications). JSON output, check the `ok` field. Run `macli --help` to list subcommands.
```

## Install

### Homebrew (recommended)

```sh
brew tap ljh-sh/macli
brew install macli
```

Or one-liner:

```sh
brew install ljh-sh/macli/macli
```

### Direct binary

Download from [Releases](https://github.com/ljh-sh/macli/releases):

```sh
curl -L https://github.com/ljh-sh/macli/releases/latest/download/macli-darwin-universal.tar.xz | tar xJ -
sudo mv bin/macli /usr/local/bin/
```

The `universal` tarball contains a fat Mach-O (arm64 + x86_64) — works on both Apple Silicon and Intel Macs.

### eget

Via [x-cmd eget](https://x-cmd.com/install/macli) — downloads the right release asset and puts it on PATH:

```sh
x eget ljh-sh/macli        # download and install
x eget use ljh-sh/macli    # install to ~/.local/bin
```

### Build from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/macli
cd macli
swift build -c release
.release-artifacts/darwin-arm64/bin/macli --help   # after .x-cmd/release darwin-arm64
```

---

## SMC sensors — the core

The headline use case. `macli smc` reads hardware sensors that macOS exposes only through private frameworks.

### What is SMC?

The **System Management Controller (SMC)** is an Apple controller embedded in every Mac. It monitors and reports:

- CPU / GPU / SoC die temperatures
- PMU voltage rails (`PPPW`, `PCPC`, …)
- PMU current rails
- Fan speeds (Intel Macs)
- Battery state and power draw

On Intel Macs, SMC is queried through `IOKit.framework`'s private AppleSMC API using 4-character keys (`TCXC`, `TG0P`, …). On Apple Silicon (M1–M4), the same data moved to a HID sensor hub — the keys are entirely different (`PMU tdie1`, `PMU tdie2`, …) and undocumented.

References — the projects that mapped this out:

- [dkorunic/iSMC](https://github.com/dkorunic/iSMC) — Go CLI, comprehensive SMC key catalog (Intel + Apple Silicon)
- [beltex/SMCKit](https://github.com/beltex/SMCKit) — Swift SMC library, the classic Intel-era reference
- [freedomtan/sensors](https://github.com/freedomtan/sensors) — early Apple Silicon IOKit exploration

### Why not Python / PyObjC?

Reading one sensor takes ~30 lines of C: open the `AppleSMC` / `AppleHID` IOService, serialize the key, call `IOConnectCallScalarMethod`, unpack the returned struct. The keys are private, the structs are private, the call convention changed between Intel and Apple Silicon.

PyObjC can call public frameworks, but the SMC key space is **private**. Reaching it from Python means ctypes-level struct packing that breaks with every macOS release. There is no `pip install` path that keeps up with Apple Silicon's new key namespace.

### Why macli?

macli wraps the same private APIs in a Swift binary linked against the native IOKit / HID frameworks. The binary is small (~400 KB), starts in ~50ms, and returns structured output:

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

### Design: agent-oriented

macli deliberately stays **dumb**. It does **not**:

- compute thermal indexes or "feels-like" temperatures
- aggregate, average, or window
- render charts, colors, or progress bars
- decide what's "hot" or "abnormal"

It returns raw sensor values, full stop. Decisions belong to the caller — which is the point. awk, jq, and python are already good at post-processing:

```sh
macli smc temp --tsv | awk -F'\t' '$2 > 80 {print $1, "OVERHEAT"}'
macli smc temp --tsv | sort -t$'\t' -k2 -n | tail -5    # 5 hottest sensors
```

This keeps `macli --help` short (saves tokens when an LLM loads it as context) and lets you reach for the tool you already know. The CLI is the API; the shell is the glue.

### `smc86` — Intel legacy, sunset track

`smc86` is the Intel-Mac counterpart, same interface. It will be removed when Intel Macs go EOL.

---

## Streaming monitor

`monitor` samples sensor sources on an interval and streams TSV — one row per sample. Single process, no subprocess fork per poll, no Python interpreter per tick. Designed as a long-running pipe stage for `awk`.

```sh
macli monitor --interval 1 --metrics smc_temp,smc_curr
macli monitor --count 10 --interval 0.5 --metrics smc_temp \
  | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print "avg:", sum/n}'
```

Flags:

- `--interval N` — seconds between samples (supports decimals, default 1.0)
- `--metrics list` — comma-separated sources (default: all)
- `--count N` — exit after N samples (default: infinite, Ctrl-C to stop)

The header row locks the column order; subsequent rows match positionally. `awk -F'\t'` is the intended downstream.

Why this matters: polling sensors with a shell loop (`while; do macli smc temp; sleep 1; done`) costs ~50ms of binary startup per iteration. `monitor` pays that once and streams samples at sub-millisecond marginal cost.

---

## EventKit — calendar / event / reminder

`EventKit.framework` is Apple's native API for Calendar and Reminders. macli wraps it for the shell — JSON output, no AppleScript involved.

```sh
macli cal ls                                # list calendars
macli event ls --calendar Work --today      # today's events
macli reminder add --list Shopping "Buy milk"
macli aka set work <calendar-id>            # alias calendar IDs for stable refs
```

Why not `osascript`?

- **osascript routes through AppleScript + the Calendar app** — cold start loads AppleScript component, Calendar.app RPC channel, and permission prompts. Often the first call blocks for seconds waiting for the user to grant access.
- **macli links `EventKit.framework` directly** and requests permission via the standard macOS TCC prompt once. Subsequent calls are in-process.
- **JSON output** instead of AppleScript list syntax — parseable by `jq`, no string munging.

Use cases: dashboards, CI notifiers ("next event in 5 min"), reminder batching, automation hooks that need stable calendar references (`aka`).

---

## Notifications / TTS / Speech

```sh
macli notify send --title "Done" "build finished"
macli speak text "Hello"
macli speak voices                          # list 180 voices
macli speech langs                          # list 63 recognition languages
```

These cover the cases where `osascript -e 'display notification'` / `say` work but are awkward to script (voice enumeration, batch sends). `speech langs` enumerates `SFSpeechRecognizer.supportedLocales()` for reference.

---

## Output conventions

- **Snapshot commands**: JSON with `{"ok": bool, ...}` (default). `--tsv` for awk-friendly.
- **Streaming commands** (`monitor`): TSV only, header on first line.
- **Errors**: `{"ok": false, "error": "...", "hint": "..."}` — never silent.

## Code signature

macli ships with **ad-hoc signature** (not Apple Developer ID). The Homebrew formula strips `com.apple.quarantine` automatically. For manual install, run:

```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```

## Binary size

- ~400 KB per arch (arm64 / x86_64)
- ~830 KB universal (fat Mach-O, arm64 + x86_64)
- ~110 KB arm64 tar.xz / ~130 KB x64 tar.xz / ~222 KB universal tar.xz

Single static-ish binary. No Python runtime, no PyObjC bridge, no ctypes layer.

## FAQ

**"macli cannot be opened because the developer cannot be verified"**
macli ships with ad-hoc signature (no Apple Developer ID). For direct-download installs, strip the quarantine attribute:
```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```
The Homebrew formula does this automatically.

**`brew install macli` says "trust" or refuses to run the formula**
Homebrew 6 added a trust step for third-party taps. Run `brew trust ljh-sh/macli` once, then `brew install macli`.

**`macli cal ls` / `event ls` hangs for seconds on first call**
macOS TCC is prompting for Calendar access. Click the system dialog to grant. Subsequent calls are instant. Check System Settings → Privacy & Security → Calendars if you missed the prompt.

**`macli smc86 ...` returns empty results on Apple Silicon**
Expected. `smc86` queries the Intel-Mac SMC key space, which Apple cleared on Apple Silicon. Use `macli smc` (not `smc86`) on M-series Macs. `smc86` is kept for Intel Macs and will be removed when they go EOL.

**Can macli run on Linux / Windows?**
No. It wraps Apple-private frameworks (IOKit, HID, EventKit, Speech) that exist only on macOS.

**Do I need `sudo`?**
No. All subcommands run as the invoking user. Sensor reads go through user-space IOKit / HID APIs.

**How is this different from iStats / smcFanControl / stats?**
Those are end-user tools (Ruby gem, fan-control app, menu-bar GUI). macli is a **CLI for scripts and agents** — JSON/TSV output, no GUI, no Ruby runtime, designed to be called from shell pipes and LLM tool use.

**Is there a Python wrapper?**
Not needed. `subprocess.run(["macli", "smc", "temp"], ...)` + `json.loads` is 3 lines and gives you the full schema. A wrapper would only hide it.

## License

Apache 2.0 — see [LICENSE.txt](LICENSE.txt).

## Development

- [DEV.md](DEV.md) — build, test, release commands
- Issue tracker and design notes: [`macli-mneme`](https://github.com/ljh-sh/macli-mneme) (private)
