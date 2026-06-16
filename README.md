# macli

> macOS native binary for things shell/python can't do.

**macli** is a small Swift-compiled CLI that exposes private macOS APIs (HID, IOKit, Speech, EventKit) which are painful or impossible to call from Python/-shell. It is **not** a "every macOS tool combined" — only the parts where `subprocess` + `osascript` + PyObjC genuinely struggle.

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

### Build from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/macli
cd macli
swift build -c release
.release-artifacts/darwin-arm64/bin/macli --help   # after .x-cmd/release darwin-arm64
```

## Subcommands

### `smc` — Apple Silicon SMC sensors (HID)

```sh
macli smc temp        # temperatures (JSON, default)
macli smc temp --tsv  # TSV output for awk
macli smc volt        # PMU voltage rails
macli smc curr        # PMU current rails
macli smc all         # everything
```

### `smc86` — Intel SMC sensors (legacy, sunset track)

Same interface as `smc`, for Intel Macs. Will be removed when Intel Macs go EOL.

### `monitor` — Streaming TSV monitor

Single process, all metric sources. Designed for `awk` post-processing:

```sh
macli monitor --interval 1 --metrics smc_temp,smc_curr
macli monitor --count 10 --interval 0.5 --metrics smc_temp \
  | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print "avg:", sum/n}'
```

Flags: `--interval N` (decimal seconds), `--metrics list`, `--count N` (exit after N samples).

### EventKit family

```sh
macli cal ls                                # list calendars
macli event ls --calendar Work --today      # today's events
macli reminder add --list Shopping "Buy milk"
macli aka set work <calendar-id>            # alias for calendar IDs
```

### Notifications / TTS / Speech

```sh
macli notify send --title "Done" "build finished"
macli speak text "Hello"
macli speak voices                          # list 180 voices
macli speech recognize audio.m4a            # transcribe
macli speech langs                          # list 63 languages
```

## Output conventions

- **Snapshot commands**: JSON with `{"ok": bool, ...}` (default). `--tsv` for awk-friendly.
- **Streaming commands** (`monitor`): TSV only, header on first line.
- **Errors**: `{"ok": false, "error": "...", "hint": "..."}` — never silent.

JSON example:

```json
{
  "ok": true,
  "source": "HID",
  "sensors": [{"name": "PMU tdie1", "value": 57.5, "unit": "°C"}],
  "count": 45
}
```

## Code signature

macli ships with **ad-hoc signature** (not Apple Developer ID). The Homebrew formula strips `com.apple.quarantine` automatically. For manual install, run:

```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```

## What macli is not

If a feature can be done with `subprocess` + system CLI (`pmset`, `system_profiler`, `ioreg`, `airport`, `networksetup`), `osascript`, or clean PyObjC, it belongs to [`x-bash/mac`](https://github.com/x-bash/mac) — not macli.

macli's scope: private frameworks, HID/IOKit/kext communication, reverse-engineered protocols, high-frequency polling.

## Binary size

- ~370 KB per arch (arm64 / x86_64)
- ~220 KB universal (fat Mach-O)
- ~105 KB compressed (tar.xz)

## License

Apache 2.0 — see [LICENSE.txt](LICENSE.txt).

## Development

- [DEV.md](DEV.md) — build, test, release commands
- Dev roadmap, stories, design decisions live in [`macli-mneme`](https://github.com/ljh-sh/macli-mneme) (private)

## Related

- [`x-bash/mac`](https://github.com/x-bash/mac) — script layer that calls macli
- [`x-bash/gpu`](https://github.com/x-bash/gpu), [`x-bash/cpu`](https://github.com/x-bash/cpu), [`x-bash/display`](https://github.com/x-bash/display) — ctypes hacks that macli is gradually replacing
