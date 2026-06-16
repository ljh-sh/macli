# macli

> macOS system tools for AI agents. Native Apple frameworks. AI-friendly JSON/TSV output.

**macli** exposes parts of macOS that are normally hard to reach from a shell — SMC sensors, streaming monitor, calendar/reminders, speech recognition. Single Swift binary, fast startup, output designed for both humans and pipes.

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

## Quickstart

```sh
macli smc temp                                    # CPU/GPU temperatures as JSON
macli smc temp --tsv                              # TSV for awk
macli monitor --count 10 --interval 0.5 --metrics smc_temp \
  | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print "avg:", sum/n}'
macli cal ls                                      # list calendars
macli notify send --title "Done" "build finished"
```

## Subcommands

### `smc` — Apple Silicon SMC sensors

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

## Binary size

- ~400 KB per arch (arm64 / x86_64)
- ~830 KB universal (fat Mach-O, arm64 + x86_64)
- ~110 KB arm64 tar.xz / ~130 KB x64 tar.xz / ~222 KB universal tar.xz

## License

Apache 2.0 — see [LICENSE.txt](LICENSE.txt).

## Development

- [DEV.md](DEV.md) — build, test, release commands
- Issue tracker and design notes: [`macli-mneme`](https://github.com/ljh-sh/macli-mneme) (private)
