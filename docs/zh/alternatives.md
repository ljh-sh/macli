---
layout: default
title: 替代方案
lang: zh
---

# 替代方案

macli 不是读取 macOS 内部状态的唯一方式。下面是与我们考虑过的工具/做法的对比。

## 传感器 / 温度工具

| 工具 | 语言 | GUI | Apple Silicon | 说明 |
|---|---|---|---|---|
| [iStats](https://github.com/Chris911/iStats) | Ruby | 否 | 否 | 仅 Intel；最后发布于 2018 |
| [smcFanControl](https://github.com/hholtmann/smcFanControl) | Objective-C | 是 | 部分 | 设置最低风扇转速的 macOS app |
| [stats](https://github.com/exelban/stats) | Swift | 是 | 是 | 菜单栏面板 |
| [iSMC](https://github.com/dkorunic/iSMC) | Go | 否 | 是 | 最接近的竞品；Go runtime 增加约 5 MB |
| [SMCKit](https://github.com/beltex/SMCKit) | Swift | 否 | 否 | 仅 Intel 的库，无 CLI |
| **macli** | Swift | 否 | 是 | ~400 KB，JSON/TSV，流式，无 runtime |

### iSMC

[iSMC](https://github.com/dkorunic/iSMC) 是最接近的竞品，Go CLI，拥有 Intel 和 Apple Silicon 的完整 SMC key 目录。我们选择 macli 是因为：

- Go 二进制携带 runtime；macli strip 后约 400 KB。
- macli 把 EventKit、流式监控、显示器/GPU 命令整合在一个工具里。
- macli 的输出 schema 为 LLM agent 设计（`{"ok": true, ...}` 信封）。

### stats

[stats](https://github.com/exelban/stats) 是漂亮的菜单栏面板，适合可视化监控。macli 面向脚本化管道和需要可解析输出的 agent。

### SMCKit

[SMCKit](https://github.com/beltex/SMCKit) 是 Intel SMC 的 Swift 库。它没有 CLI、没有流式、不支持 Apple Silicon。macli 从同一问题空间出发，但优先服务 shell 和 Apple Silicon。

## Shell / Python / AppleScript 方案

### 用 PyObjC 的 Python 脚本

通过 PyObjC 读取电池数据是可行的，因为 `AppleSmartBattery` 走 IOKit 暴露。但 SMC key 空间是私有的。可靠访问需要 `ctypes` struct 封装和逐个 key 逆向。每次 macOS 更新都可能破坏脚本。

macli 把同样的 IOKit/HID 调用编译进二进制，携带稳定的 struct 布局。

### AppleScript 封装

AppleScript 可以通过 Calendar.app 读日历，但：

- 慢（AppleScript 组件冷启动 + app RPC）。
- 返回本地化的人类可读字符串。
- 每次冷启动都触发权限提示。

macli 直接链接 EventKit，返回 JSON。

### 用 `ioreg` 和 `system_profiler` 的 shell 循环

`ioreg` 和 `system_profiler` 能暴露部分相同数据，但：

- `ioreg` 输出是冗长的 XML/plist，需要后处理。
- `system_profiler` 慢，不适合流式。
- SMC/HID key 无法通过它们干净地获取。

macli 在内部解析这些来源（例如用 `system_profiler` 取 SSD 信息），并在上面提供稳定的 JSON/TSV 层。

## 日历 / 提醒工具

| 方案 | 输出 | 速度 | 说明 |
|---|---|---|---|
| `osascript` / AppleScript | 人类可读字符串 | 慢（冷启动） | 本地化、解析脆弱 |
| macli EventKit | JSON | 快（授权后进程内） | 字段名稳定，无 app RPC |

## 什么时候用别的工具

- 需要详细 SSD SMART 数据（TBW、磨损百分比、媒体错误）→ 用 **smartctl**。
- 需要可视化菜单栏面板 → 用 **stats**。
- 想要成熟的 Go 传感器目录 → 用 **iSMC**。
- 只有脚本化一个无公开 API 的 app 时才用 **AppleScript**。

macli 填补的空隙是：小巧、原生、可脚本化、可解析、Apple Silicon 优先。
