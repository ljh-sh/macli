---
layout: default
title: Subcommands
---

# Subcommand reference

This page lists every `macli <subcmd>` function, its options, and the meaning of every output field.

<div class="toc" markdown="1">

- [Output conventions](#output-conventions)
- [Command tree](#command-tree)
- [SMC sensors](#smc-sensors)
  - [`macli smc temp`](#macli-smc-temp)
  - [`macli smc volt`](#macli-smc-volt)
  - [`macli smc curr`](#macli-smc-curr)
  - [`macli smc power`](#macli-smc-power)
  - [`macli smc batt`](#macli-smc-batt)
  - [`macli smc fans`](#macli-smc-fans)
  - [`macli smc all`](#macli-smc-all)
  - [`macli smc86 ...`](#macli-smc86-intel-legacy)
- [`macli battery`](#macli-battery)
- [`macli ssd`](#macli-ssd)
- [`macli gpu info`](#macli-gpu-info)
- [`macli display`](#macli-display)
- [`macli monitor`](#macli-monitor)
- [`macli cal`](#macli-cal)
- [`macli event`](#macli-event)
- [`macli reminder`](#macli-reminder)
- [`macli aka`](#macli-aka)

</div>

## Output conventions

| Form | Command | Default | With `--tsv` |
|---|---|---|---|
| Snapshot | `smc`, `battery`, `ssd`, `gpu`, `display`, `cal`, `event`, `reminder`, `aka` | JSON | TSV |
| Streaming | `monitor` | TSV only | — |

All snapshot commands return a top-level envelope:

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

Commands never fail silently.

## Command tree

```
macli
├── smc      # Apple Silicon SMC sensors (HID)
│   ├── temp
│   ├── volt
│   ├── curr
│   ├── power
│   ├── batt
│   ├── fans
│   └── all
├── smc86    # Intel SMC sensors (legacy)
│   ├── temp
│   ├── volt
│   ├── curr
│   ├── power
│   ├── batt
│   ├── fans
│   └── all
├── battery  # Battery health and power telemetry
├── ssd      # NVMe / SSD info from system_profiler
├── gpu
│   └── info # GPU name, cores, unified memory
├── display
│   ├── list       # list online displays
│   └── brightness # read or set brightness
├── monitor  # streaming TSV monitor
├── cal      # calendars
│   ├── ls
│   ├── la
│   ├── add
│   └── rm
├── event    # calendar events
│   ├── ls
│   ├── show
│   ├── add
│   ├── edit
│   └── rm
├── reminder # reminders
│   ├── ls
│   ├── show
│   ├── add
│   ├── rm
│   ├── complete
│   └── undo
└── aka      # calendar / list aliases
    ├── ls
    ├── set
    └── rm
```

## SMC sensors

`macli smc` reads hardware sensors on Apple Silicon (M1/M2/M3/M4/M5) through the HID sensor hub. `macli smc86` is the Intel-Mac counterpart; it returns empty or an error on Apple Silicon because Apple cleared the Intel SMC key space.

### `macli smc temp`

Temperature sensors reported by the Apple Silicon HID thermal sensor hub.

```sh
macli smc temp        # JSON
macli smc temp --tsv  # TSV
```

JSON output:

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | `true` if the read succeeded |
| `source` | string | Always `"HID"` |
| `sensors` | array | Sensor objects |
| `sensors[].name` | string | Human-readable sensor name, e.g. `"PMU tdie1"` |
| `sensors[].value` | number | Temperature in degrees Celsius |
| `sensors[].unit` | string | Always `"°C"` |
| `count` | int | Number of sensors |
| `note` | string | Scope caveat: only HID thermal sensors are enumerated |

TSV columns: `name`, `value`, `unit`.

### `macli smc volt`

Voltage rails from the PMU.

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success flag |
| `source` | string | `"HID"` |
| `sensors[].name` | string | Rail name, e.g. `"PMU vldo1"` |
| `sensors[].value` | number | Voltage |
| `sensors[].unit` | string | e.g. `"V"` |
| `count` | int | Sensor count |

### `macli smc curr`

Current sensors from the PMU.

| Field | Type | Meaning |
|---|---|---|
| `sensors[].name` | string | Rail name, e.g. `"PMU ildo1"` |
| `sensors[].value` | number | Current |
| `sensors[].unit` | string | e.g. `"A"` |

### `macli smc power`

Power telemetry derived from `AppleSmartBattery` / adapter details.

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success flag |
| `source` | string | `"IOKit"` |
| `sensors[]` | array | Power sensor objects |
| `sensors[].name` | string | `"Battery Power"`, `"AC Adapter Power"` |
| `sensors[].value` | number | Power in watts |
| `sensors[].unit` | string | `"W"` |
| `count` | int | Sensor count |
| `note` | string | `"No battery found; power readings unavailable"` when applicable |

### `macli smc batt`

Battery status via IOKit. See [`macli battery`](#macli-battery) for the full standalone output.

### `macli smc fans`

Apple Silicon Macs use passive cooling, so this returns an empty fan list with a note explaining why.

### `macli smc all`

Returns everything from `temp`, `volt`, `curr`, `power`, and `batt` in one JSON object. In TSV mode, sections are separated by blank lines and `#` comments.

### `macli smc86` (Intel legacy)

Same subcommands as `macli smc`, but reads the Intel SMC key space (keys such as `TCXC`, `TG0P`, fan IDs, etc.). Returns empty or an error on Apple Silicon. Will be removed when Intel Macs reach end-of-life.

Intel sensor objects also include a `key` field — the 4-character SMC key.


## `macli battery`

Battery snapshot via IOKit (`AppleSmartBattery`).

```sh
macli battery         # JSON (default)
macli battery --tsv   # TSV
macli battery --plist # raw IORegistry XML plist
```

JSON output fields:

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | `true` if a battery was found and read |
| `present` | bool | Whether a battery is present |
| `source` | string | `"IOKit"` |
| `status` | string | `"AC"` or `"Battery"` |
| `externalConnected` | bool | Is AC adapter plugged in |
| `isCharging` | bool | Is the battery currently charging |
| `designCapacity` | int | Design capacity in mAh |
| `maxCapacity` | int | Maximum capacity in mAh |
| `currentCapacity` | int | Current charge in mAh |
| `nominalChargeCapacity` | int | Nominal charge capacity in mAh |
| `healthPercent` | number | `maxCapacity / designCapacity * 100` |
| `voltage` | int | Pack voltage in mV |
| `amperage` | int | Instant amperage in mA |
| `instantAmperage` | int | Instant amperage (alternate register) in mA |
| `designWh` | number | Design energy in Wh |
| `currentWh` | number | Current energy in Wh |
| `temperature` | number | Pack temperature in °C |
| `virtualTemperature` | number | Virtual temperature in °C |
| `cycleCount` | int | Charge cycle count |
| `timeRemaining` | int | Estimated time remaining in minutes |
| `avgTimeToEmpty` | int | Average time to empty in minutes |
| `avgTimeToFull` | int | Average time to full in minutes |
| `serialNumber` | string | Battery serial |
| `deviceName` | string | Device name from registry |
| `cellVoltages` | array | Per-cell voltages in V |
| `qmax` | array | Qmax values per cell |
| `manufactureDate` | int | Manufacture date code |
| `batterySerial` | string | BatteryData serial |
| `adapter` | object | `{watts, voltage, current, description}` |
| `inputPower` | number | Adapter watts |
| `charger` | object | `{voltage, current}` |
| `systemPower` | number | System power draw in W |
| `batteryPower` | number | Battery power draw in W |
| `systemVoltageIn` | number | System input voltage |
| `systemCurrentIn` | number | System input current |
| `note` | string | Present when no battery is found |

<div class="note" markdown="1">

**Scripting example** — alert when battery health drops below 80%:

```sh
macli battery | jq -e '.healthPercent < 80' && echo "consider replacement"
```

</div>

## `macli ssd`

SSD / NVMe drive info and SMART status from `system_profiler SPNVMeDataType`.

```sh
macli ssd
```

JSON output:

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success flag |
| `source` | string | `"system_profiler"` |
| `controllers` | array | One entry per NVMe controller |
| `controllers[].name` | string | Controller name |
| `controllers[].drives[]` | array | Drives under this controller |
| `drives[].name` | string | Drive name |
| `drives[].model` | string | Device model |
| `drives[].serial` | string | Serial number |
| `drives[].revision` | string | Firmware revision |
| `drives[].bsdName` | string | e.g. `disk0` |
| `drives[].size` | string | Human-readable size |
| `drives[].sizeInBytes` | int | Size in bytes |
| `drives[].smartStatus` | string | SMART status string |
| `drives[].trimSupport` | string | TRIM support status |
| `drives[].removable` | string | Removable media flag |
| `drives[].volumes[]` | array | Volumes on this drive |
| `volumes[].name` | string | Volume name |
| `volumes[].bsdName` | string | Volume BSD name |
| `volumes[].size` | string | Human-readable size |
| `volumes[].sizeInBytes` | int | Volume size in bytes |
| `volumes[].content` | string | Content type |
| `note` | string | Notes about SMART scope |

<div class="note warning" markdown="1">

macOS does not expose detailed SMART log pages (wear percentage, TBW, media errors) through a public API. For that data, use `smartctl`:

```sh
brew install smartmontools
smartctl -a disk0
```

</div>

## `macli gpu info`

GPU information via Metal and `AGXAccelerator` in IOKit.

```sh
macli gpu info        # JSON
macli gpu info --tsv  # TSV
```

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success flag |
| `source` | string | `"Metal/IOKit"` |
| `name` | string | GPU name, e.g. `"Apple M3 Pro"` |
| `hasUnifiedMemory` | bool | Whether CPU and GPU share memory |
| `recommendedMaxWorkingSetSizeBytes` | int | Recommended max GPU memory in bytes |
| `coreCount` | int | GPU core count (Apple Silicon) |

## `macli display`

Display brightness and info via the private `DisplayServices` framework.

### `macli display list`

List online displays.

```sh
macli display list        # JSON
macli display list --tsv  # TSV
```

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success flag |
| `source` | string | `"DisplayServices"` |
| `displays[]` | array | Online displays |
| `displays[].id` | int | Display ID in hex (e.g. `0x1`) |
| `displays[].main` | bool | Is the main display |
| `displays[].builtIn` | bool | Is the built-in display |
| `displays[].active` | bool | Is currently active |
| `displays[].brightness` | number | Brightness level `0.0–1.0` if readable |

### `macli display brightness`

Read or set built-in display brightness.

```sh
macli display brightness             # read
macli display brightness --set 0.5   # set to 50%
```

When reading, the schema is the same as `display list`. When setting, the output is:

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success flag |
| `displayID` | int | Affected display ID |
| `brightness` | number | Clamped brightness `0.0–1.0` |
| `error` | string | Present on failure |

## `macli monitor`

Streaming TSV monitor. Single process, all metric sources, downstream `awk`-friendly.

```sh
macli monitor
macli monitor --interval 1 --metrics smc_temp,smc_curr
macli monitor --count 10 --interval 0.5
```

Flags:

| Flag | Type | Default | Meaning |
|---|---|---|---|
| `--interval` | number | `1.0` | Seconds between samples (decimals allowed) |
| `--metrics` | string | all | Comma-separated source names |
| `--count` | int | infinite | Exit after N samples |

Available metric sources:

| Source | Data |
|---|---|
| `smc_temp` | HID temperature sensors |
| `smc_volt` | HID voltage sensors |
| `smc_curr` | HID current sensors |
| `battery_power` | Battery / AC adapter power in W |
| `gpu_metrics` | GPU utilization (experimental, Apple Silicon only) |

Output is TSV. The first line is the header; each subsequent line starts with a Unix timestamp followed by metric values. Column order is locked by the header.

```
ts        smc_temp_PMU_tdie1  smc_temp_PMU_tdie2  battery_power_Battery_Power
1718812800.000  57.5                48.0                8.2
```

Why this matters: a shell loop (`while; do macli smc temp; sleep 1; done`) costs ~50 ms of binary startup per iteration. `monitor` pays that once and streams samples at sub-millisecond marginal cost.


## `macli cal`

Calendar management via `EventKit.framework`.

<div class="note" markdown="1">

macOS will prompt for Calendar access the first time you run a `cal` / `event` command. Grant it in the system dialog. If you miss the prompt, go to **System Settings → Privacy & Security → Calendars**.

</div>

### `macli cal ls`

List event calendars.

```sh
macli cal ls
```

| Field | Type | Meaning |
|---|---|---|
| `calendars[]` | array | Event calendars |
| `calendars[].uid` | string | Stable calendar identifier |
| `calendars[].name` | string | Calendar title |
| `calendars[].kind` | string | `"event"` |
| `calendars[].src` | string | Account source, e.g. `"iCloud"` |
| `calendars[].color` | string | Hex color, e.g. `"#FF0000"` |
| `calendars[].canEdit` | bool | Can content be modified |
| `calendars[].calType` | string | `local`, `caldav`, `exchange`, `subscription`, `birthday`, `unknown` |
| `calendars[].isSubscribed` | bool | Is a subscribed calendar |
| `calendars[].isImmutable` | bool | Is read-only / immutable |

### `macli cal la`

List **all** calendars, including reminder lists.

### `macli cal add`

Create a new calendar or reminder list.

```sh
macli cal add --name Work --color #FF0000
macli cal add --name Shopping --type reminder
```

| Flag | Required | Default | Meaning |
|---|---|---|---|
| `--name` | yes | — | Calendar title |
| `--type` | no | `event` | `event` or `reminder` |
| `--color` | no | — | Hex color |

Output: the created calendar object.

### `macli cal rm`

Delete a calendar or reminder list. Requires `--yes`.

```sh
macli cal rm <calendar-id> --yes
macli cal rm <list-id> --type reminder --yes
```

| Flag | Required | Default | Meaning |
|---|---|---|---|
| `--type` | no | `event` | `event` or `reminder` |
| `--yes` | yes | — | Confirm destructive deletion |

Output: `{"deletedCalendarId": "..."}`

## `macli event`

Calendar event management.

### `macli event ls`

List events in a date range.

```sh
macli event ls --calendar work --today
macli event ls --calendar work --week
macli event ls --calendar work --from 2024-01-01 --to 2024-01-31
```

| Flag | Required | Meaning |
|---|---|---|
| `--calendar` | yes | Calendar ID or alias |
| `--from` | * | Start date (ISO8601 or `today`/`tomorrow`/`+7`) |
| `--to` | * | End date |
| `--today` | * | Today's events |
| `--week` | * | This week's events |
| `--month` | * | This month's events |

\* Either `--today` / `--week` / `--month` or both `--from` and `--to` are required.

Output fields:

| Field | Type | Meaning |
|---|---|---|
| `events[]` | array | Matching events |
| `events[].uid` | string | Event identifier |
| `events[].title` | string | Event title |
| `events[].cal.uid` | string | Calendar ID |
| `events[].cal.name` | string | Calendar name |
| `events[].isAllDay` | bool | All-day event |
| `events[].start` | string | ISO8601 start date |
| `events[].end` | string | ISO8601 end date |
| `events[].loc` | string | Location |
| `events[].note` | string | Notes |
| `events[].link` | string | URL |
| `events[].hasAlarm` | bool | Has an alarm |
| `events[].hasRepeat` | bool | Is repeating |
| `count` | int | Number of events |

### `macli event show <id>`

Show a single event by ID.

### `macli event add`

Create an event.

```sh
macli event add --calendar work --title Meeting \
  --start 2024-01-15T10:00 --end 2024-01-15T11:00 \
  --location "Room A" --notes "Weekly sync" --alarm 15
```

| Flag | Required | Meaning |
|---|---|---|
| `--calendar` | yes | Calendar ID or alias |
| `--title` | yes | Event title |
| `--start` | yes | Start date/time |
| `--end` | yes | End date/time |
| `--location` | no | Location |
| `--notes` | no | Notes |
| `--all-day` | no | All-day event |
| `--alarm` | no | Alarm minutes before start |

### `macli event edit <id>`

Update an event.

```sh
macli event edit <id> --title "New title" --start 2024-01-15T11:00
```

### `macli event rm <id> --yes`

Delete an event.

## `macli reminder`

Reminder management.

<div class="note" markdown="1">

macOS will prompt for Reminders access the first time you run a `reminder` command. Grant it in the system dialog. If you miss the prompt, go to **System Settings → Privacy & Security → Reminders**.

</div>

### `macli reminder ls`

List reminders in a list.

```sh
macli reminder ls --list work
macli reminder ls --list work --completed true
```

| Flag | Required | Meaning |
|---|---|---|
| `--list` | yes | List ID or alias |
| `--completed` | no | Filter by `true` or `false` |

Output fields:

| Field | Type | Meaning |
|---|---|---|
| `reminders[]` | array | Matching reminders |
| `reminders[].uid` | string | Reminder identifier |
| `reminders[].title` | string | Title |
| `reminders[].list.uid` | string | List ID |
| `reminders[].list.name` | string | List name |
| `reminders[].isDone` | bool | Completed |
| `reminders[].doneAt` | string | Completion date ISO8601 |
| `reminders[].due` | string | Due date ISO8601 |
| `reminders[].note` | string | Notes |
| `reminders[].link` | string | URL |
| `reminders[].prio` | int | Priority |
| `count` | int | Number of reminders |

### `macli reminder show <id>`

Show a single reminder.

### `macli reminder add`

Create a reminder.

```sh
macli reminder add --list work --title "Buy milk" --due 2024-01-15
```

| Flag | Required | Meaning |
|---|---|---|
| `--list` | yes | List ID or alias |
| `--title` | yes | Title |
| `--due` | no | Due date/time |
| `--priority` | no | Priority integer |
| `--notes` | no | Notes |

### `macli reminder rm <id> --yes`

Delete a reminder.

### `macli reminder complete <id>`

Mark a reminder as complete.

### `macli reminder undo <id>`

Undo completion of a reminder.

## `macli aka`

Manage aliases for calendar and reminder list IDs. Calendar IDs are UUIDs that can change across devices or Apple ID migrations; aliases give you stable references in scripts.

### `macli aka ls`

List all aliases.

```json
{
  "aka": [
    {"name": "work", "id": "..."},
    {"name": "home", "id": "..."}
  ],
  "count": 2,
  "configPath": "..."
}
```

### `macli aka set <name> <id>`

Set an alias.

```sh
macli aka set work <calendar-id>
```

### `macli aka rm <name>`

Remove an alias.

```sh
macli aka rm work
```
