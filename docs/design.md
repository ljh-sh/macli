---
layout: default
title: Design & principles
---

# Design & principles

macli is deliberately small. It wraps only the parts of macOS that are hard to reach from shell, Python, or AppleScript and exposes them as a predictable CLI.

## Agent-oriented CLI

macli follows the x-cmd agent-tool design principle: **minimal context with maximum flexibility**.

It stays **dumb** — it does **not** compute thermal indexes, aggregate data, render charts, or decide what's "hot". It returns raw sensor values and system state, full stop. Decisions belong to the caller:

```sh
macli smc temp --tsv | awk -F'\t' '$2 > 80 {print $1, "OVERHEAT"}'
macli smc temp --tsv | sort -t$'\t' -k2 -n | tail -5
```

This keeps `macli --help` short, which saves tokens when an LLM loads it as context. The CLI is the API; the shell is the glue.

## Design goals

| Goal | How macli does it |
|---|---|
| Native Apple frameworks | IOKit, HID, EventKit, Metal, DisplayServices — linked directly |
| No extra runtime | Single Swift binary, ~400 KB per arch, no Python/Ruby/Go runtime |
| Machine-readable output | JSON snapshots, TSV streams, stable field names |
| Never silent | Every command returns `{"ok": bool, ...}` or an error object |
| Shell-first | Output is shaped for `jq`, `awk`, `sort`, `gnuplot`, `tail` |
| Streaming friendly | `monitor` runs once and streams samples; no fork per poll |
| Apple Silicon first | `smc` uses the HID sensor hub; Intel kept alive via `smc86` |

## Output schema

Snapshot commands share a single envelope:

```json
{
  "ok": true,
  "source": "HID",
  ...
}
```

On failure:

```json
{
  "ok": false,
  "error": "...",
  "hint": "..."
}
```

This means an LLM can wrap any macli call with the same pattern: run the command, parse JSON, check `ok`, then read the data. No special-case exit-code parsing, no stderr scraping.

## Why JSON and TSV?

- **JSON** is parseable by `jq`, Python, Node.js, and every LLM tool-use interface. Field names are stable regardless of system language.
- **TSV** is the natural input format for `awk`, `sort`, `uniq`, and spreadsheets. One row per record, tabs as delimiters, no nested structures.

macli never invents a new format. It speaks the formats the shell already speaks.

## Architecture

```
┌─────────────────────────────────────────┐
│  CLI layer (Sources/cli/*.swift)        │  <- argument parsing, output formatting
├─────────────────────────────────────────┤
│  Controller layer (Sources/ctrl/*.swift)│  <- framework wrappers, data shaping
├─────────────────────────────────────────┤
│  Apple frameworks / private APIs        │  <- IOKit, HID, EventKit, Metal, ...
└─────────────────────────────────────────┘
```

- **CLI layer** (`Sources/cli/`) owns `Cmd` conformance, option metadata, and JSON/TSV serialization. It does not talk to hardware directly.
- **Controller layer** (`Sources/ctrl/`) encapsulates framework access and returns dictionaries or model structs.
- **Objective-C helpers** (`Sources/HidSensorObjC/`) handle the lowest-level IOKit HID and battery plumbing that is more ergonomic in C/ObjC than Swift.

This separation makes it easy to add a new subcommand without touching framework internals, and easy to add a new sensor source without touching CLI formatting.

## What macli does not do

- **No GUI.** There is no menu-bar icon, no chart, no window. macli is a pipe stage.
- **No aggregation.** Averages, rolling windows, and thresholds belong in `awk`/`jq`.
- **No alerting.** `notify-send` / `osascript -e 'display notification'` are one-liners on top of macli.
- **No cross-platform support.** macli wraps Apple-private frameworks that exist only on macOS.
- **No cloud sync.** macli reads local state only.

Keeping these out keeps the binary small, the help short, and the behavior predictable.

## Streaming monitor design

`monitor` is a single long-running process. It:

1. Builds a registry of metric sources.
2. Pre-samples each selected source to lock column order.
3. Prints a TSV header.
4. Sleeps for `--interval`, samples, prints one TSV row, repeats.

Because HID sensor arrays are positionally stable on the same machine, values align with the header by index. If the count diverges (rare), it falls back to name matching. This makes the stream robust enough for unattended pipelines.

## Versioning and stability

macli uses semantic versioning. Output field names are treated as part of the public API and only changed in major or minor releases with deprecation notes. See the [`changelog/`](https://github.com/ljh-sh/macli/tree/main/changelog) directory for release-by-release notes.
