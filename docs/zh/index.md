---
layout: default
title: 首页
lang: zh
---

<div class="hero">
  <h1>macli</h1>
  <p>最小上下文，最大灵活性 —— 面向 AI agent 的 macOS 系统工具。原生 Apple framework。AI 友好的 JSON/TSV 输出。</p>
  <div class="cta">
    <a class="btn primary" href="{{ '/zh/install' | relative_url }}">安装</a>
    <a class="btn secondary" href="{{ '/zh/subcommands' | relative_url }}">命令参考</a>
    <a class="btn secondary" href="https://github.com/ljh-sh/macli" target="_blank" rel="noopener">GitHub</a>
  </div>
</div>

## macli 是什么？

**macli** 把 macOS 系统内部能力做成干净的 CLI。SMC 传感器、流式监控、日历/提醒 —— 全都能从 shell 管道或 LLM agent 调用，全是 JSON/TSV。单一 ~400 KB Swift 二进制。无 Python runtime，无 `osascript` 开销，无 GUI。

当你（或你的 AI agent）需要问 macOS 一些 `system_profiler` / `ioreg` / `osascript` 答不出或答得很烂的问题：

- *CPU 此刻的核心温度*
- *以 1 Hz 把传感器流式喂给 awk*
- *今天日历的 JSON*

## 一览

```sh
macli smc temp                              # CPU/GPU 温度 JSON
macli gpu info                              # GPU 名称、核心数、统一内存
macli display brightness                    # 内置显示器亮度
macli monitor --count 10 --interval 1       # 流式输出 10 个样本给 awk
macli cal ls                                # 日历列表 JSON
```

输出格式：成功时 `{"ok": true, ...}`，失败时 `{"ok": false, "error": "...", "hint": "..."}`。绝不会静默失败。

## 面向 AI agent

把这行 prompt 贴给 Claude Code、Cursor 或任意 agent：

```md
用 `macli` 取 macOS 系统状态（传感器 / 日历 / 提醒）。若未安装：`brew install ljh-sh/cli/macli`。输出为 JSON，检查 `ok` 字段。子命令列表 `macli --help`。
```

## 接下来

- [安装 macli]({{ '/zh/install' | relative_url }}) — Homebrew、直接下载、eget 或源码编译
- [命令参考]({{ '/zh/subcommands' | relative_url }}) — 每个子命令、选项和输出字段
- [电池字段详解]({{ '/zh/battery' | relative_url }}) — `macli battery` 完整字段与诊断脚本
- [设计与原则]({{ '/zh/design' | relative_url }}) — macli 为什么长这样
- [设计原则]({{ '/zh/design-principles' | relative_url }}) — 五项核心原则
- [为什么用 macli？]({{ '/zh/why' | relative_url }}) — 为什么用 CLI 而不是 shell/Python/AppleScript
- [常见问题]({{ '/zh/faq' | relative_url }}) — 权限、输出格式、平台差异等
- [替代方案]({{ '/zh/alternatives' | relative_url }}) — 与 iStats、iSMC、stats 等对比
- [验证发布]({{ '/zh/verifying-releases' | relative_url }}) — cosign 签名与 SLSA 来源证明
