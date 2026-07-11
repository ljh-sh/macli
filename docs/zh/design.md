---
layout: default
title: 设计与原则
lang: zh
---

# 设计与原则

macli 刻意保持小巧。它只封装从 shell、Python 或 AppleScript 难以触及的 macOS 部分，并以可预测的 CLI 暴露出来。

## 面向 agent 的 CLI

macli 遵循 x-cmd 的 agent-tool 设计原则：**最小上下文，最大灵活性**。

它保持**笨拙** —— 不计算散热指数、不聚合数据、不渲染图表、也不决定什么叫“过热”。它只返回原始传感器值和系统状态。决策交给调用方：

```sh
macli smc temp --tsv | awk -F'\t' '$2 > 80 {print $1, "OVERHEAT"}'
macli smc temp --tsv | sort -t$'\t' -k2 -n | tail -5
```

这样 `macli --help` 保持简短，LLM 把它当上下文加载时更省 token。CLI 就是 API；shell 是胶水。

## 设计目标

| 目标 | macli 的实现方式 |
|---|---|
| 原生 Apple framework | 直接链接 IOKit、HID、EventKit、Metal、DisplayServices |
| 无额外 runtime | 单一 Swift 二进制，~400 KB/架构，无 Python/Ruby/Go runtime |
| 机器可读输出 | JSON 快照、TSV 流、稳定字段名 |
| 绝不静默 | 每条命令返回 `{"ok": bool, ...}` 或错误对象 |
| shell 优先 | 输出为 `jq`、`awk`、`sort`、`gnuplot`、`tail` 优化 |
| 流式友好 | `monitor` 启动一次持续输出；每次采样不 fork |
| Apple Silicon 优先 | `smc` 使用 HID 传感器 hub；Intel 通过 `smc86` 保留 |

## 输出 schema

快照命令共享同一个信封：

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

这意味着 LLM 可以用同一模式包装任意 macli 调用：执行命令、解析 JSON、检查 `ok`、再读取数据。不需要特殊处理退出码，也不需要刮取 stderr。

## 为什么用 JSON 和 TSV？

- **JSON** 可被 `jq`、Python、Node.js 和每个 LLM tool-use 接口解析。字段名稳定，不受系统语言影响。
- **TSV** 是 `awk`、`sort`、`uniq` 和电子表格的自然输入格式。每行一条记录，制表符分隔，无嵌套结构。

macli 不发明新格式。它只说 shell 已经在说的格式。

## 架构

```
┌─────────────────────────────────────────┐
│  CLI 层 (Sources/cli/*.swift)           │  <- 参数解析、输出格式化
├─────────────────────────────────────────┤
│  控制层 (Sources/ctrl/*.swift)          │  <- framework 封装、数据塑形
├─────────────────────────────────────────┤
│  Apple framework / 私有 API             │  <- IOKit、HID、EventKit、Metal ...
└─────────────────────────────────────────┘
```

- **CLI 层**（`Sources/cli/`）负责 `Cmd` 协议、选项元数据和 JSON/TSV 序列化。不直接访问硬件。
- **控制层**（`Sources/ctrl/`）封装 framework 访问，返回字典或模型结构。
- **Objective-C 辅助**（`Sources/HidSensorObjC/`）处理最低层的 IOKit HID 和电池操作，这些在 C/ObjC 里比 Swift 更顺手。

这种分离让新增子命令不用碰 framework 内部，新增传感器源也不用碰 CLI 格式化。

## macli 不做什么

- **没有 GUI。** 没有菜单栏图标、没有图表、没有窗口。macli 是一个管道阶段。
- **不做聚合。** 平均值、滑动窗口、阈值判断属于 `awk`/`jq`。
- **不做告警。** `osascript -e 'display notification'` 或 `notify-send` 在 macli 上层只需一行。
- **不做跨平台。** macli 只包装 macOS 上的 Apple 私有 framework。
- **不云同步。** macli 只读取本地状态。

把这些排除在外，二进制保持小巧、help 保持简短、行为保持可预测。

## 流式监控设计

`monitor` 是一个单一长进程：

1. 构建指标源注册表。
2. 对每个选中源预采样，锁定列顺序。
3. 打印 TSV 表头。
4. 按 `--interval` 睡眠、采样、打印一行 TSV，循环往复。

因为 HID 传感器数组在同一台机器上是位置稳定的，值按索引与表头对齐。如果数量出现偏差（很少见），则回退到按名称匹配。这让无人值守管道足够健壮。

## 版本与稳定性

macli 使用语义化版本。输出字段名被视为公共 API 的一部分，只在主版本或次版本变更，并附带弃用说明。版本发布说明见 [`changelog/`](https://github.com/ljh-sh/macli/tree/main/changelog) 目录。
