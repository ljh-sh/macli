---
layout: default
title: Home
---

<div class="hero">
  <h1>macli</h1>
  <p>Minimal context with maximum flexibility — macOS system tools for AI agents. Native Apple frameworks. AI-friendly JSON/TSV output.</p>
  <div class="cta">
    <a class="btn primary" href="{{ '/install' | relative_url }}">Install</a>
    <a class="btn secondary" href="{{ '/subcommands' | relative_url }}">Command reference</a>
    <a class="btn secondary" href="https://github.com/ljh-sh/macli" target="_blank" rel="noopener">GitHub</a>
  </div>
</div>

## What is macli?

**macli** turns macOS system internals into a clean CLI. SMC sensors, streaming monitor, calendar/reminders — all callable from shell pipes or LLM agents, all JSON/TSV. One ~400 KB Swift binary. No Python runtime, no `osascript` overhead, no GUI.

Use it when you (or your AI agent) need to ask macOS something that `system_profiler` / `ioreg` / `osascript` either can't answer or answer badly:

- *CPU die temperature right now*
- *Stream 1 Hz sensor readings into awk*
- *Today's calendar as JSON*

## At a glance

```sh
macli smc temp                              # CPU/GPU temps as JSON
macli gpu info                              # GPU name, cores, unified memory
macli display brightness                    # built-in display brightness
macli monitor --count 10 --interval 1       # stream 10 samples to awk
macli cal ls                                # list calendars as JSON
```

Output schema: `{"ok": true, ...}` on success, `{"ok": false, "error": "...", "hint": "..."}` on failure. Never silent.

## For AI agents

Paste this one-line prompt into Claude Code, Cursor, or any agent's system prompt:

```md
Use `macli` for macOS system state (sensors / calendar / reminders). Install if missing: `brew install ljh-sh/cli/macli`. JSON output, check `ok`. Run `macli --help` for subcommands.
```

## Where to go next

- [Install macli]({{ '/install' | relative_url }}) — Homebrew, direct binary, eget, or build from source
- [Command reference]({{ '/subcommands' | relative_url }}) — every subcommand, option, and output field
- [Battery field reference]({{ '/battery' | relative_url }}) — complete `macli battery` fields and diagnostic scripts
- [Design & principles]({{ '/design' | relative_url }}) — why macli is shaped the way it is
- [Design principles]({{ '/design-principles' | relative_url }}) — the five core principles
- [Why macli?]({{ '/why' | relative_url }}) — why a CLI instead of a shell/Python/AppleScript
- [FAQ]({{ '/faq' | relative_url }}) — common questions about permissions, output formats, and usage
- [Alternatives]({{ '/alternatives' | relative_url }}) — how macli compares to iStats, iSMC, stats, and others
- [Verifying releases]({{ '/verifying-releases' | relative_url }}) — cosign signatures and SLSA provenance
