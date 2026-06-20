---
layout: default
title: Why macli?
---

# Why macli?

> macli deliberately stays small and only wraps things that are hard from shell / Python / AppleScript.

## Why does this belong in a CLI rather than a script?

### 1. Private frameworks are hard to call from scripts

Reading one SMC sensor takes roughly 30 lines of C: open the `AppleSMC` / `AppleHID` IOService, serialize the key, call `IOConnectCallScalarMethod`, unpack the returned struct. The keys are private, the structs are private, and the call convention changed between Intel and Apple Silicon.

PyObjC can call public frameworks, but the SMC key space is **private**. Reaching it from Python means `ctypes`-level struct packing that breaks with every macOS release. There is no `pip install` path that keeps up with Apple Silicon's new key namespace.

A compiled Swift binary can link the frameworks directly and ship the correct struct layouts for the current macOS version.

### 2. AppleScript is slow and lossy for EventKit

`osascript` routes through AppleScript → Calendar.app RPC → permission prompts. Every cold start loads the AppleScript component. It returns human-formatted strings like `{calendar "Work", calendar "Home"}` that require regex on localized strings.

macli links `EventKit.framework` directly, requests permission once via the standard TCC prompt, and returns stable JSON. Subsequent calls are in-process.

### 3. Subprocess overhead matters for streaming

A naive monitoring loop:

```sh
while true; do macli smc temp; sleep 1; done
```

costs ~50 ms of binary startup per iteration. `macli monitor` pays startup once and streams samples at sub-millisecond marginal cost. For long-running pipelines, that is the difference between usable and not usable.

### 4. A single binary is easier for LLM agents to reason about

LLM agents work best with short, predictable tools. One binary, one help page, one JSON schema. They do not need to reason about Python environments, Ruby gems, Homebrew dependencies, or whether `osascript` returned English or Japanese.

### 5. Shell is the best glue language

macli does not try to replace your shell. It gives the shell clean data so you can do what the shell is good at:

```sh
macli smc temp --tsv | sort -t$'\t' -k2 -n | tail -5
macli battery | jq -e '.healthPercent < 80'
macli monitor --metrics battery_power --interval 1 | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print sum/n}'
```

## What is the SMC?

The **System Management Controller (SMC)** is an Apple controller embedded in every Mac. It monitors and reports CPU / GPU / SoC die temperatures, PMU voltage rails, PMU current rails, fan speeds (Intel Macs), and battery state.

On Intel Macs, SMC is queried through IOKit's private AppleSMC API using 4-character keys (`TCXC`, `TG0P`, …). On Apple Silicon (M1–M4), the same data moved to a HID sensor hub — the keys are entirely different (`PMU tdie1`, `PMU tdie2`, …) and undocumented.

## When should you use macli?

Use macli when you need:

- Real-time hardware sensor data for dashboards or logging.
- Battery / SSD health checks in CI or dotfiles.
- Calendar or reminder data in scripts without AppleScript.
- A stable, small tool that LLM agents can call through shell.

Do not use macli when:

- You are on Linux or Windows. macli is macOS-only.
- You need detailed SMART wear data. Use `smartctl`.
- You need a GUI dashboard. Use [stats](https://github.com/exelban/stats).
