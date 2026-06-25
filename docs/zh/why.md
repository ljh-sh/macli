---
layout: default
title: 为什么用 macli？
lang: zh
---

# 为什么用 macli？

> macli 刻意保持小巧，只封装从 shell / Python / AppleScript 难以做到的事情。

## 为什么这件事适合放在 CLI 里，而不是脚本里？

### 1. 私有 framework 很难从脚本调用

读取一个 SMC 传感器大概需要 30 行 C：打开 `AppleSMC` / `AppleHID` IOService，序列化 key，调用 `IOConnectCallScalarMethod`，解包返回的 struct。这些 key 是私有的，struct 是私有的，Intel 和 Apple Silicon 之间的调用约定还变了。

PyObjC 能调用公开 framework，但 SMC key 空间是**私有的**。要从 Python 访问它，意味着 `ctypes` 级别的 struct 封装，而且每次 macOS 更新都可能失效。不存在一条 `pip install` 路径能跟上 Apple Silicon 的新 key 命名空间。

编译型 Swift 二进制可以直接链接 framework，并携带适合当前 macOS 版本的 struct 布局。

### 2. AppleScript 对 EventKit 又慢又容易丢信息

`osascript` 走 AppleScript → Calendar.app RPC → 权限提示。每次冷启动都要加载 AppleScript 组件。返回的是人类可读的字符串，比如 `{calendar "Work", calendar "Home"}`，需要针对本地化字符串写正则解析。

macli 直接链接 `EventKit.framework`，通过标准 TCC 提示请求一次权限，然后返回稳定的 JSON。后续调用都在进程内完成。

### 3. 流式监控时子进程开销很显眼

一个朴素的监控循环：

```sh
while true; do macli smc temp; sleep 1; done
```

每次迭代大约消耗 50 ms 的二进制启动时间。`macli monitor` 只付一次启动成本，然后以亚毫秒边际成本流式采样。对长时间运行的管道来说，这是能用和不能用的区别。

### 4. LLM agent 更容易理解单一二进制

LLM agent 最适合简短、可预测的工具。一个二进制、一份 help、一个 JSON schema。它们不需要考虑 Python 环境、Ruby gem、Homebrew 依赖，也不需要关心 `osascript` 返回的是英文还是日文。

### 5. shell 才是最好的胶水语言

macli 不想取代 shell。它给 shell 提供干净的数据，让 shell 做它擅长的事：

```sh
macli smc temp --tsv | sort -t$'\t' -k2 -n | tail -5
macli battery | jq -e '.healthPercent < 80'
macli monitor --metrics battery_power --interval 1 | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print sum/n}'
```

## SMC 是什么？

**系统管理控制器（System Management Controller，SMC）** 是每台 Mac 内置的 Apple 控制器。它监控并上报 CPU / GPU / SoC 核心温度、PMU 电压轨、PMU 电流轨、风扇转速（Intel Mac）和电池状态。

在 Intel Mac 上，通过 IOKit 私有 AppleSMC API 用 4 字符 key（如 `TCXC`、`TG0P` …）查询。在 Apple Silicon（M1–M4）上，同样的数据移到了 HID 传感器 hub —— key 完全不同（如 `PMU tdie1`、`PMU tdie2` …）且未公开文档。

## 什么时候用 macli？

适合用 macli：

- 实时硬件传感器数据，用于面板或日志。
- CI 或 dotfiles 里的电池 / SSD 健康检查。
- 脚本里读取日历或提醒，不想用 AppleScript。
- 需要一个稳定、小巧、LLM agent 可通过 shell 调用的工具。

不适合用 macli：

- 你在 Linux 或 Windows 上。macli 只支持 macOS。
- 你需要详细的 SMART 磨损数据。请用 `smartctl`。
- 你需要 GUI 面板。请用 [stats](https://github.com/exelban/stats)。
