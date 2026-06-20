---
layout: default
title: Alternatives
---

# Alternatives considered

macli is not the only way to read macOS internals. Here is how it compares to the tools and approaches we considered.

## Sensor / temperature tools

| Tool | Language | GUI | Apple Silicon | Notes |
|---|---|---|---|---|
| [iStats](https://github.com/Chris911/iStats) | Ruby | No | No | Intel-only; last release 2018 |
| [smcFanControl](https://github.com/hholtmann/smcFanControl) | Objective-C | Yes | Partial | macOS app for setting minimum fan speed |
| [stats](https://github.com/exelban/stats) | Swift | Yes | Yes | Menu-bar dashboard |
| [iSMC](https://github.com/dkorunic/iSMC) | Go | No | Yes | Closest peer; Go runtime adds ~5 MB |
| [SMCKit](https://github.com/beltex/SMCKit) | Swift | No | No | Intel-only library, no CLI |
| **macli** | Swift | No | Yes | ~400 KB, JSON/TSV, streaming, no runtime |

### iSMC

[iSMC](https://github.com/dkorunic/iSMC) is the closest peer. It is a Go CLI with a comprehensive SMC key catalog for both Intel and Apple Silicon. We chose to build macli because:

- Go binaries carry a runtime; macli is ~400 KB stripped.
- macli adds EventKit, streaming monitor, and display/GPU commands in one tool.
- macli's output schema is designed for LLM agents (`{"ok": true, ...}` envelope).

### stats

[stats](https://github.com/exelban/stats) is a beautiful menu-bar dashboard. It is perfect for visual monitoring. macli is for scripted pipelines and agents that need parseable output.

### SMCKit

[SMCKit](https://github.com/beltex/SMCKit) is a Swift library for Intel SMC. It has no CLI, no streaming, and no Apple Silicon support. macli started from the same problem space but targets the shell and Apple Silicon first.

## Shell / Python / AppleScript approaches

### A Python script with PyObjC

Reading battery data through PyObjC is possible because `AppleSmartBattery` is exposed via IOKit. But the SMC key space is private. Reaching it reliably requires `ctypes` struct packing and per-key reverse engineering. Every macOS update risks breaking the script.

macli compiles the same IOKit/HID calls into a binary with stable struct layouts.

### An AppleScript wrapper

AppleScript can read calendars through Calendar.app, but:

- It is slow (AppleScript component cold start + app RPC).
- It returns localized, human-formatted strings.
- It triggers permission prompts on every cold start.

macli links EventKit directly and returns JSON.

### A shell loop calling `ioreg` and `system_profiler`

`ioreg` and `system_profiler` can expose some of the same data, but:

- `ioreg` output is verbose XML/plist that needs post-processing.
- `system_profiler` is slow and not suitable for streaming.
- SMC/HID keys are not exposed through these tools in a clean way.

macli parses these sources internally (e.g. `system_profiler` for SSD info) and gives you a stable JSON/TSV layer on top.

## Calendar / reminder tools

| Approach | Output | Speed | Notes |
|---|---|---|---|
| `osascript` / AppleScript | Human-formatted strings | Slow (cold start) | Localized, fragile parsing |
| macli EventKit | JSON | Fast (in-process after permission) | Stable field names, no app RPC |

## When to use something else

- Use **smartctl** for detailed SSD SMART data (TBW, wear percentage, media errors).
- Use **stats** for a visual menu-bar dashboard.
- Use **iSMC** if you want a mature Go-based sensor catalog.
- Use **AppleScript** only when you need to script an app that has no public API.

macli sits in the gap: small, native, scriptable, parseable, and Apple Silicon-first.
