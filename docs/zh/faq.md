---
layout: default
title: 常见问题
lang: zh
---

# 常见问题

## macli 是什么？为什么不直接用 `system_profiler` / `ioreg` / `osascript`？

**macli** 是一个小巧的 Swift CLI，把 macOS 系统内部状态变成干净、可解析的输出。SMC 传感器、电池/SSD 健康、显示器亮度、日历/提醒事项 —— 全是 JSON 或 TSV，都能从 shell 管道或 LLM agent 调用。

`system_profiler`、`ioreg`、`osascript` 也能暴露*部分*相同数据，但它们不是为自动化设计的：

- `system_profiler` 慢且不支持流式。
- `ioreg` 返回冗长的 XML/plist，需要后处理。
- `osascript` 走 Calendar.app，返回本地化的人类可读字符串，每次调用都要付 AppleScript 冷启动成本。

macli 直接链接原生 framework（IOKit、HID、EventKit、Metal、DisplayServices），只请求一次权限，返回稳定的 JSON/TSV。

## macli 为什么需要权限？

- **SMC / HID 传感器访问** 不需要用户授权；它走用户空间 IOKit。
- **日历和提醒事项** 命令使用 `EventKit.framework`，受 macOS TCC（透明度、同意和控制）保护。第一次运行 `macli cal ls`、`event ls` 或 `reminder` 命令时，macOS 会弹出权限请求。

所有 macli 命令都不需要 `sudo`。

## 为什么必须从 Terminal.app / iTerm / Warp 运行，而不是裸 CLI 进程？

macOS TCC 把权限授予**父应用程序**，而不是二进制本身。如果你从裸子进程、SSH 会话或没有控制终端的 launchd 作业运行 `macli cal ls`，系统可能会静默拒绝访问，因为没有 app bundle 可归因。

通常的解决办法是从已被授予日历/提醒事项权限的终端运行 macli：

- Terminal.app
- iTerm2
- Warp
- VS Code 终端
- 任何出现在 **系统设置 → 隐私与安全性 → 日历 / 提醒事项** 中的终端

终端被允许后，从该终端启动的脚本会继承访问权限。

## 如何授权？

1. 从终端运行一次日历或提醒事项命令，例如
   ```sh
   macli cal ls
   ```
2. 在系统对话框中点击**允许**。
3. 如果错过了弹窗，前往 **系统设置 → 隐私与安全性 → 日历**（或**提醒事项**）并启用你正在使用的终端。

对于直接下载安装，可能还需要去除一次隔离属性：

```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```

Homebrew 会自动完成这一步。

## 有哪些输出格式？什么时候用 JSON，什么时候用 TSV？

- **JSON**（快照命令默认）：最适合 `jq`、Python、Node.js 和 LLM tool-use 接口。字段名稳定，不受系统语言影响。
- **TSV**（`--tsv`）：最适合 `awk`、`sort`、`uniq`、电子表格和长时间运行的管道。每行一条记录，制表符分隔。
- **流式监控**（`macli monitor`）：仅 TSV，表头锁定列顺序。

程序需要解析嵌套或命名字段时用 JSON；想把输出当作 shell 管道里的行时用 TSV。

## 为什么没有 GUI？

macli 刻意只是一个管道阶段，不是面板。已经有很棒的 GUI 工具如 [stats](https://github.com/exelban/stats)。macli 保持小巧、可脚本化，以便与 `awk`、`jq`、`gnuplot` 和 LLM agent 组合。没有 GUI 让二进制保持 ~400 KB，接口更可预测。

## 如何在脚本或 AI agent 中使用 macli？

把 JSON 信封当作契约：

```sh
macli battery | jq -e '.healthPercent < 80'
macli smc temp --tsv | awk -F'\t' '$2 > 80 {print $1, "OVERHEAT"}'
```

给 agent 的 system prompt：

```md
Use `macli` for macOS system state (sensors / calendar / reminders). Install if missing: `brew install ljh-sh/cli/macli`. JSON output, check `ok`. Run `macli --help` for subcommands.
```

每条命令成功返回 `{"ok": true, ...}`，失败返回 `{"ok": false, "error": "...", "hint": "..."}`。

## 为什么有些命令只支持 Apple Silicon 或 Intel？

Apple 在 Intel 和 Apple Silicon 之间改变了传感器栈：

- **Apple Silicon（M1–M4）**：传感器位于 HID 传感器 hub，key 如 `PMU tdie1`。使用 `macli smc`。
- **Intel Mac**：传感器位于经典 SMC，key 为 4 字符如 `TCXC`。使用 `macli smc86`。

同一个 universal 二进制包含两条代码路径；子命令选择走哪条。某些新功能（如 `monitor` 中实验性的 GPU 利用率）仅支持 Apple Silicon，因为底层 framework 计数器在 Intel 硬件上不存在。

## 开发文档和故事放在哪里？

- 已发布的文档站点位于 GitHub 的 [`docs/`](https://github.com/ljh-sh/macli/tree/main/docs) 目录，通过 GitHub Pages 提供服务。
- 版本发布说明位于 [`changelog/`](https://github.com/ljh-sh/macli/tree/main/changelog)。
- 架构和设计原理见 [`docs/design.md`]({{ '/zh/design' | relative_url }})。
- 与其他工具的对比见 [`docs/alternatives.md`]({{ '/zh/alternatives' | relative_url }})。

---

发现 bug 或有疑问？[在 GitHub 上提交 issue](https://github.com/ljh-sh/macli/issues)。
