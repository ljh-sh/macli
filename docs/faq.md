---
layout: default
title: FAQ
---

# Frequently Asked Questions

## What is macli and why not just use `system_profiler` / `ioreg` / `osascript`?

**macli** is a small Swift CLI that turns macOS system internals into clean, parseable output. SMC sensors, battery/SSD health, display brightness, calendar/reminders — all JSON or TSV, all callable from shell pipes or LLM agents.

`system_profiler`, `ioreg`, and `osascript` can expose *some* of the same data, but they are not built for automation:

- `system_profiler` is slow and not streamable.
- `ioreg` returns verbose XML/plist that needs post-processing.
- `osascript` routes through Calendar.app, returns localized human-formatted strings, and pays an AppleScript cold-start cost on every call.

macli links native frameworks directly (IOKit, HID, EventKit, Metal, DisplayServices), requests permissions once, and returns stable JSON/TSV.

## Why does macli need permissions?

- **SMC / HID sensor access** does not require user-granted permissions; it runs through user-space IOKit.
- **Calendar and Reminders** commands use `EventKit.framework`, which is protected by macOS TCC (Transparency, Consent, and Control). The first time you run `macli cal ls`, `event ls`, or a `reminder` command, macOS prompts you to allow access.

No `sudo` is required for any macli command.

## Why must I run it from Terminal.app / iTerm / Warp instead of a bare CLI process?

macOS TCC grants permissions to the **parent application**, not the binary itself. If you run `macli cal ls` from a bare subprocess, an SSH session, or a launchd job with no controlling terminal, the system may silently deny access because there is no app bundle to attribute the permission to.

The fix is usually to run macli from a terminal that has been granted Calendar/Reminders access:

- Terminal.app
- iTerm2
- Warp
- VS Code terminal
- Any terminal that appears in **System Settings → Privacy & Security → Calendars / Reminders**

Once the terminal is allowed, scripts launched *from* that terminal inherit the access.

## How do I grant permissions?

1. Run any calendar or reminders command once from your terminal, e.g.
   ```sh
   macli cal ls
   ```
2. Click **Allow** in the system dialog.
3. If you missed the dialog, go to **System Settings → Privacy & Security → Calendars** (or **Reminders**) and enable the terminal you are using.

For direct-download installs, you may also need to strip the quarantine attribute once:

```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```

Homebrew does this automatically.

## What output formats are available and when to use JSON vs TSV?

- **JSON** (default for snapshot commands): best for `jq`, Python, Node.js, and LLM tool-use interfaces. Field names are stable regardless of system language.
- **TSV** (`--tsv`): best for `awk`, `sort`, `uniq`, spreadsheets, and long-running pipelines. One row per record, tabs as delimiters.
- **Streaming monitor** (`macli monitor`): TSV only, with a header row that locks column order.

Use JSON when a program needs to parse nested or named fields. Use TSV when you want to treat the output as rows in a shell pipeline.

## Why is there no GUI?

macli is deliberately a pipe stage, not a dashboard. There are already excellent GUI tools like [stats](https://github.com/exelban/stats). macli stays small and scriptable so it can be composed with `awk`, `jq`, `gnuplot`, and LLM agents. No GUI keeps the binary ~400 KB and the interface predictable.

## How do I use macli from a script or AI agent?

Use the JSON envelope as the contract:

```sh
macli battery | jq -e '.healthPercent < 80'
macli smc temp --tsv | awk -F'\t' '$2 > 80 {print $1, "OVERHEAT"}'
```

For agents, paste this into the system prompt:

```md
Use `macli` for macOS system state (sensors / calendar / reminders). Install if missing: `brew install ljh-sh/cli/macli`. JSON output, check `ok`. Run `macli --help` for subcommands.
```

Every command returns `{"ok": true, ...}` on success or `{"ok": false, "error": "...", "hint": "..."}` on failure.

## Why are some commands Apple Silicon only or Intel only?

Apple changed the sensor stack between Intel and Apple Silicon:

- **Apple Silicon (M1–M4)**: sensors live in a HID sensor hub with keys like `PMU tdie1`. Use `macli smc`.
- **Intel Macs**: sensors live in the classic SMC with 4-character keys like `TCXC`. Use `macli smc86`.

The same universal binary contains both code paths; the subcommand selects which one to use. Some newer features (e.g. experimental GPU utilization in `monitor`) are Apple Silicon only because the underlying framework counters do not exist on Intel hardware.

## Where are dev docs / stories kept?

- The published docs site lives in [`docs/`](https://github.com/ljh-sh/macli/tree/main/docs) on GitHub and is served via GitHub Pages.
- Release-by-release notes live in [`changelog/`](https://github.com/ljh-sh/macli/tree/main/changelog).
- Architecture and design rationale are in [`docs/design.md`]({{ '/design' | relative_url }}).
- Comparison with other tools is in [`docs/alternatives.md`]({{ '/alternatives' | relative_url }}).

---

Found a bug or have a question? [Open an issue on GitHub](https://github.com/ljh-sh/macli/issues).
