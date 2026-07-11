---
layout: default
title: 子命令
lang: zh
---

# 子命令参考

本页列出所有 `macli <subcmd>` 功能、选项以及每个输出字段的含义。

<div class="toc" markdown="1">

- [输出约定](#输出约定)
- [命令树](#命令树)
- [SMC 传感器](#smc-传感器)
  - [`macli smc temp`](#macli-smc-temp)
  - [`macli smc volt`](#macli-smc-volt)
  - [`macli smc curr`](#macli-smc-curr)
  - [`macli smc power`](#macli-smc-power)
  - [`macli smc batt`](#macli-smc-batt)
  - [`macli smc fans`](#macli-smc-fans)
  - [`macli smc all`](#macli-smc-all)
  - [`macli smc86 ...`](#macli-smc86-intel-遗留)
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

## 输出约定

| 形式 | 命令 | 默认 | 加 `--tsv` |
|---|---|---|---|
| 快照 | `smc`、`battery`、`ssd`、`gpu`、`display`、`cal`、`event`、`reminder`、`aka` | JSON | TSV |
| 流式 | `monitor` | 仅 TSV | — |

所有快照命令都返回顶层信封：

```json
{
  "ok": true,
  "source": "HID",
  ...
}
```

失败时：

```json
{
  "ok": false,
  "error": "...",
  "hint": "..."
}
```

命令绝不会静默失败。

## 命令树

```
macli
├── smc      # Apple Silicon SMC 传感器（HID）
│   ├── temp
│   ├── volt
│   ├── curr
│   ├── power
│   ├── batt
│   ├── fans
│   └── all
├── smc86    # Intel SMC 传感器（遗留）
│   ├── temp
│   ├── volt
│   ├── curr
│   ├── power
│   ├── batt
│   ├── fans
│   └── all
├── battery  # 电池健康与电源遥测
├── ssd      # 从 system_profiler 获取 NVMe / SSD 信息
├── gpu
│   └── info # GPU 名称、核心数、统一内存
├── display
│   ├── list       # 列出在线显示器
│   └── brightness # 读取或设置亮度
├── monitor  # 流式 TSV 监控
├── cal      # 日历
│   ├── ls
│   ├── la
│   ├── add
│   └── rm
├── event    # 日历事件
│   ├── ls
│   ├── show
│   ├── add
│   ├── edit
│   └── rm
├── reminder # 提醒事项
│   ├── ls
│   ├── show
│   ├── add
│   ├── rm
│   ├── complete
│   └── undo
└── aka      # 日历 / 列表别名
    ├── ls
    ├── set
    └── rm
```

## SMC 传感器

`macli smc` 在 Apple Silicon（M1/M2/M3/M4/M5）上通过 HID 传感器 hub 读取硬件传感器。`macli smc86` 是 Intel Mac 的对应命令；在 Apple Silicon 上会返回空或错误，因为 Apple 清除了 Intel SMC key 空间。

### `macli smc temp`

Apple Silicon HID 热传感器 hub 上报的温度传感器。

```sh
macli smc temp        # JSON
macli smc temp --tsv  # TSV
```

JSON 输出：

| 字段 | 类型 | 含义 |
|---|---|---|
| `ok` | bool | 读取成功为 `true` |
| `source` | string | 固定 `"HID"` |
| `sensors` | array | 传感器对象数组 |
| `sensors[].name` | string | 人类可读名称，如 `"PMU tdie1"` |
| `sensors[].value` | number | 摄氏温度 |
| `sensors[].unit` | string | 固定 `"°C"` |
| `count` | int | 传感器数量 |
| `note` | string | 范围说明：仅枚举 HID 热传感器 |

TSV 列：`name`、`value`、`unit`。

### `macli smc volt`

PMU 电压轨。

| 字段 | 类型 | 含义 |
|---|---|---|
| `ok` | bool | 成功标志 |
| `source` | string | `"HID"` |
| `sensors[].name` | string | 轨名称，如 `"PMU vldo1"` |
| `sensors[].value` | number | 电压值 |
| `sensors[].unit` | string | 如 `"V"` |
| `count` | int | 传感器数量 |

### `macli smc curr`

PMU 电流传感器。

| 字段 | 类型 | 含义 |
|---|---|---|
| `sensors[].name` | string | 轨名称，如 `"PMU ildo1"` |
| `sensors[].value` | number | 电流值 |
| `sensors[].unit` | string | 如 `"A"` |

### `macli smc power`

从 `AppleSmartBattery` / 适配器详情派生的电源遥测。

| 字段 | 类型 | 含义 |
|---|---|---|
| `ok` | bool | 成功标志 |
| `source` | string | `"IOKit"` |
| `sensors[]` | array | 功率传感器对象 |
| `sensors[].name` | string | `"Battery Power"`、`"AC Adapter Power"` |
| `sensors[].value` | number | 功率，单位瓦 |
| `sensors[].unit` | string | `"W"` |
| `count` | int | 传感器数量 |
| `note` | string | 无电池时的说明 |

### `macli smc batt`

通过 IOKit 获取电池状态。完整独立输出见 [`macli battery`](#macli-battery)。

### `macli smc fans`

Apple Silicon Mac 使用被动散热，因此返回空风扇列表并附带说明。

### `macli smc all`

在一个 JSON 对象中返回 `temp`、`volt`、`curr`、`power` 和 `batt` 的全部内容。TSV 模式下用空行和 `#` 注释分隔各节。

### `macli smc86`（Intel 遗留）

子命令与 `macli smc` 相同，但读取 Intel SMC key 空间（如 `TCXC`、`TG0P`、风扇 ID 等）。在 Apple Silicon 上返回空或错误。Intel Mac 停产时将移除。

Intel 传感器对象额外包含 `key` 字段 —— 4 字符 SMC key。


## `macli battery`

通过 IOKit（`AppleSmartBattery`）获取电池快照。

```sh
macli battery         # JSON（默认）
macli battery --tsv   # TSV
macli battery --plist # 原始 IORegistry XML plist
```

JSON 输出字段：

| 字段 | 类型 | 含义 |
|---|---|---|
| `ok` | bool | 找到并读取电池时为 `true` |
| `present` | bool | 是否存在电池 |
| `source` | string | `"IOKit"` |
| `status` | string | `"AC"` 或 `"Battery"` |
| `externalConnected` | bool | 是否连接电源适配器 |
| `isCharging` | bool | 是否正在充电 |
| `designCapacity` | int | 设计容量（mAh） |
| `maxCapacity` | int | 最大容量（mAh） |
| `currentCapacity` | int | 当前电量（mAh） |
| `nominalChargeCapacity` | int | 标称充电容量（mAh） |
| `healthPercent` | number | `maxCapacity / designCapacity * 100` |
| `voltage` | int | 电池组电压（mV） |
| `amperage` | int | 电流（mA） |
| `instantAmperage` | int | 瞬态电流（mA） |
| `designWh` | number | 设计能量（Wh） |
| `currentWh` | number | 当前能量（Wh） |
| `temperature` | number | 电池温度（°C） |
| `virtualTemperature` | number | 虚拟温度（°C） |
| `cycleCount` | int | 充电循环次数 |
| `timeRemaining` | int | 预计剩余时间（分钟） |
| `avgTimeToEmpty` | int | 平均耗尽时间（分钟） |
| `avgTimeToFull` | int | 平均充满时间（分钟） |
| `serialNumber` | string | 电池序列号 |
| `deviceName` | string | 注册表中的设备名 |
| `cellVoltages` | array | 每节电芯电压（V） |
| `qmax` | array | 每节电芯 Qmax |
| `manufactureDate` | int | 生产日期代码 |
| `batterySerial` | string | BatteryData 序列号 |
| `adapter` | object | `{watts, voltage, current, description}` |
| `inputPower` | number | 适配器功率 |
| `charger` | object | `{voltage, current}` |
| `systemPower` | number | 系统功耗（W） |
| `batteryPower` | number | 电池功耗（W） |
| `systemVoltageIn` | number | 系统输入电压 |
| `systemCurrentIn` | number | 系统输入电流 |
| `note` | string | 无电池时的说明 |

<div class="note" markdown="1">

**脚本示例** — 电池健康低于 80% 时告警：

```sh
macli battery | jq -e '.healthPercent < 80' && echo "consider replacement"
```

</div>

## `macli ssd`

从 `system_profiler SPNVMeDataType` 获取 SSD / NVMe 驱动器信息与 SMART 状态。

```sh
macli ssd
```

JSON 输出：

| 字段 | 类型 | 含义 |
|---|---|---|
| `ok` | bool | 成功标志 |
| `source` | string | `"system_profiler"` |
| `controllers` | array | 每个 NVMe 控制器一项 |
| `controllers[].name` | string | 控制器名称 |
| `controllers[].drives[]` | array | 该控制器下的驱动器 |
| `drives[].name` | string | 驱动器名称 |
| `drives[].model` | string | 设备型号 |
| `drives[].serial` | string | 序列号 |
| `drives[].revision` | string | 固件版本 |
| `drives[].bsdName` | string | 如 `disk0` |
| `drives[].size` | string | 人类可读大小 |
| `drives[].sizeInBytes` | int | 字节大小 |
| `drives[].smartStatus` | string | SMART 状态字符串 |
| `drives[].trimSupport` | string | TRIM 支持状态 |
| `drives[].removable` | string | 可移动媒体标志 |
| `drives[].volumes[]` | array | 该驱动器上的卷 |
| `volumes[].name` | string | 卷名 |
| `volumes[].bsdName` | string | 卷 BSD 名 |
| `volumes[].size` | string | 人类可读大小 |
| `volumes[].sizeInBytes` | int | 卷大小（字节） |
| `volumes[].content` | string | 内容类型 |
| `note` | string | SMART 范围说明 |

<div class="note warning" markdown="1">

macOS 不通过公开 API 暴露详细 SMART 日志页（磨损百分比、TBW、媒体错误）。需要这些数据请用 `smartctl`：

```sh
brew install smartmontools
smartctl -a disk0
```

</div>

## `macli gpu info`

通过 Metal 和 IOKit 中的 `AGXAccelerator` 获取 GPU 信息。

```sh
macli gpu info        # JSON
macli gpu info --tsv  # TSV
```

| 字段 | 类型 | 含义 |
|---|---|---|
| `ok` | bool | 成功标志 |
| `source` | string | `"Metal/IOKit"` |
| `name` | string | GPU 名称，如 `"Apple M3 Pro"` |
| `hasUnifiedMemory` | bool | CPU 与 GPU 是否共享内存 |
| `recommendedMaxWorkingSetSizeBytes` | int | 推荐最大 GPU 内存（字节） |
| `coreCount` | int | GPU 核心数（Apple Silicon） |

## `macli display`

通过私有 `DisplayServices` framework 读取/设置显示器亮度。

### `macli display list`

列出在线显示器。

```sh
macli display list        # JSON
macli display list --tsv  # TSV
```

| 字段 | 类型 | 含义 |
|---|---|---|
| `ok` | bool | 成功标志 |
| `source` | string | `"DisplayServices"` |
| `displays[]` | array | 在线显示器 |
| `displays[].id` | int | 显示器 ID（十六进制，如 `0x1`） |
| `displays[].main` | bool | 是否主显示器 |
| `displays[].builtIn` | bool | 是否内置显示器 |
| `displays[].active` | bool | 是否活跃 |
| `displays[].brightness` | number | 亮度值 `0.0–1.0`，若可读 |

### `macli display brightness`

读取或设置内置显示器亮度。

```sh
macli display brightness             # 读取
macli display brightness --set 0.5   # 设为 50%
```

读取时的 schema 与 `display list` 相同。设置时的输出为：

| 字段 | 类型 | 含义 |
|---|---|---|
| `ok` | bool | 成功标志 |
| `displayID` | int | 受影响的显示器 ID |
| `brightness` | number | 限制后的亮度 `0.0–1.0` |
| `error` | string | 失败时存在 |

## `macli monitor`

流式 TSV 监控。单一长进程，所有指标源，下游 `awk` 友好。

```sh
macli monitor
macli monitor --interval 1 --metrics smc_temp,smc_curr
macli monitor --count 10 --interval 0.5
```

参数：

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `--interval` | number | `1.0` | 采样间隔秒数（支持小数） |
| `--metrics` | string | all | 逗号分隔的源名称 |
| `--count` | int | 无限 | 采样 N 次后退出 |

可用指标源：

| 源 | 数据 |
|---|---|
| `smc_temp` | HID 温度传感器 |
| `smc_volt` | HID 电压传感器 |
| `smc_curr` | HID 电流传感器 |
| `battery_power` | 电池 / 适配器功率（W） |
| `gpu_metrics` | GPU 利用率（实验性，仅 Apple Silicon） |

输出为 TSV。第一行是表头；后续每行以 Unix 时间戳开头，后跟指标值。列顺序由表头锁定。

```
ts        smc_temp_PMU_tdie1  smc_temp_PMU_tdie2  battery_power_Battery_Power
1718812800.000  57.5                48.0                8.2
```

为什么重要：shell 循环（`while; do macli smc temp; sleep 1; done`）每次迭代大约消耗 50 ms 二进制启动时间。`monitor` 只付一次启动成本，然后以亚毫秒边际成本流式采样。


## `macli cal`

通过 `EventKit.framework` 管理日历。

<div class="note" markdown="1">

第一次运行 `cal` / `event` 命令时，macOS TCC 会请求日历权限。授予后后续调用瞬间完成。

</div>

### `macli cal ls`

列出事件日历。

```sh
macli cal ls
```

| 字段 | 类型 | 含义 |
|---|---|---|
| `calendars[]` | array | 事件日历 |
| `calendars[].uid` | string | 稳定日历标识符 |
| `calendars[].name` | string | 日历标题 |
| `calendars[].kind` | string | `"event"` |
| `calendars[].src` | string | 账户源，如 `"iCloud"` |
| `calendars[].color` | string | 十六进制颜色，如 `"#FF0000"` |
| `calendars[].canEdit` | bool | 是否可修改内容 |
| `calendars[].calType` | string | `local`、`caldav`、`exchange`、`subscription`、`birthday`、`unknown` |
| `calendars[].isSubscribed` | bool | 是否订阅日历 |
| `calendars[].isImmutable` | bool | 是否只读/不可变 |

### `macli cal la`

列出**所有**日历，包括提醒事项列表。

### `macli cal add`

新建日历或提醒事项列表。

```sh
macli cal add --name Work --color #FF0000
macli cal add --name Shopping --type reminder
```

| 参数 | 必填 | 默认值 | 含义 |
|---|---|---|---|
| `--name` | 是 | — | 日历标题 |
| `--type` | 否 | `event` | `event` 或 `reminder` |
| `--color` | 否 | — | 十六进制颜色 |

输出：创建的日历对象。

### `macli cal rm`

删除日历或提醒事项列表。需要 `--yes`。

```sh
macli cal rm <calendar-id> --yes
macli cal rm <list-id> --type reminder --yes
```

| 参数 | 必填 | 默认值 | 含义 |
|---|---|---|---|
| `--type` | 否 | `event` | `event` 或 `reminder` |
| `--yes` | 是 | — | 确认破坏性删除 |

输出：`{"deletedCalendarId": "..."}`

## `macli event`

日历事件管理。

### `macli event ls`

列出日期范围内的事件。

```sh
macli event ls --calendar work --today
macli event ls --calendar work --week
macli event ls --calendar work --from 2024-01-01 --to 2024-01-31
```

| 参数 | 必填 | 含义 |
|---|---|---|
| `--calendar` | 是 | 日历 ID 或别名 |
| `--from` | * | 开始日期（ISO8601 或 `today`/`tomorrow`/`+7`） |
| `--to` | * | 结束日期 |
| `--today` | * | 今天的事件 |
| `--week` | * | 本周事件 |
| `--month` | * | 本月事件 |

\* 必须提供 `--today` / `--week` / `--month` 之一，或同时提供 `--from` 和 `--to`。

输出字段：

| 字段 | 类型 | 含义 |
|---|---|---|
| `events[]` | array | 匹配的事件 |
| `events[].uid` | string | 事件标识符 |
| `events[].title` | string | 事件标题 |
| `events[].cal.uid` | string | 日历 ID |
| `events[].cal.name` | string | 日历名称 |
| `events[].isAllDay` | bool | 全天事件 |
| `events[].start` | string | ISO8601 开始时间 |
| `events[].end` | string | ISO8601 结束时间 |
| `events[].loc` | string | 地点 |
| `events[].note` | string | 备注 |
| `events[].link` | string | URL |
| `events[].hasAlarm` | bool | 是否有提醒 |
| `events[].hasRepeat` | bool | 是否重复 |
| `count` | int | 事件数量 |

### `macli event show <id>`

按 ID 显示单个事件。

### `macli event add`

创建事件。

```sh
macli event add --calendar work --title Meeting \
  --start 2024-01-15T10:00 --end 2024-01-15T11:00 \
  --location "Room A" --notes "Weekly sync" --alarm 15
```

| 参数 | 必填 | 含义 |
|---|---|---|
| `--calendar` | 是 | 日历 ID 或别名 |
| `--title` | 是 | 事件标题 |
| `--start` | 是 | 开始日期/时间 |
| `--end` | 是 | 结束日期/时间 |
| `--location` | 否 | 地点 |
| `--notes` | 否 | 备注 |
| `--all-day` | 否 | 全天事件 |
| `--alarm` | 否 | 开始前提醒分钟数 |

### `macli event edit <id>`

更新事件。

```sh
macli event edit <id> --title "New title" --start 2024-01-15T11:00
```

### `macli event rm <id> --yes`

删除事件。

## `macli reminder`

提醒事项管理。

<div class="note" markdown="1">

第一次运行 `reminder` 命令时，macOS TCC 会请求提醒事项权限。如果错过弹窗，前往 **系统设置 → 隐私与安全性 → 提醒事项** 开启。

</div>

### `macli reminder ls`

列出某个列表中的提醒事项。

```sh
macli reminder ls --list work
macli reminder ls --list work --completed true
```

| 参数 | 必填 | 含义 |
|---|---|---|
| `--list` | 是 | 列表 ID 或别名 |
| `--completed` | 否 | 按 `true` 或 `false` 过滤 |

输出字段：

| 字段 | 类型 | 含义 |
|---|---|---|
| `reminders[]` | array | 匹配的提醒事项 |
| `reminders[].uid` | string | 提醒事项标识符 |
| `reminders[].title` | string | 标题 |
| `reminders[].list.uid` | string | 列表 ID |
| `reminders[].list.name` | string | 列表名称 |
| `reminders[].isDone` | bool | 是否已完成 |
| `reminders[].doneAt` | string | 完成时间 ISO8601 |
| `reminders[].due` | string | 截止时间 ISO8601 |
| `reminders[].note` | string | 备注 |
| `reminders[].link` | string | URL |
| `reminders[].prio` | int | 优先级 |
| `count` | int | 提醒事项数量 |

### `macli reminder show <id>`

显示单个提醒事项。

### `macli reminder add`

创建提醒事项。

```sh
macli reminder add --list work --title "Buy milk" --due 2024-01-15
```

| 参数 | 必填 | 含义 |
|---|---|---|
| `--list` | 是 | 列表 ID 或别名 |
| `--title` | 是 | 标题 |
| `--due` | 否 | 截止时间 |
| `--priority` | 否 | 优先级整数 |
| `--notes` | 否 | 备注 |

### `macli reminder rm <id> --yes`

删除提醒事项。

### `macli reminder complete <id>`

标记为完成。

### `macli reminder undo <id>`

撤销完成。

## `macli aka`

管理日历和提醒事项列表 ID 的别名。日历 ID 是可能在设备间或 Apple ID 迁移时变化的 UUID；别名让你在脚本中使用稳定引用。

### `macli aka ls`

列出所有别名。

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

设置别名。

```sh
macli aka set work <calendar-id>
```

### `macli aka rm <name>`

移除别名。

```sh
macli aka rm work
```
