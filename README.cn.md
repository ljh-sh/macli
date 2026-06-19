# macli

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/ljh-sh/macli/badge)](https://scorecard.dev/)
[![CI](https://github.com/ljh-sh/macli/actions/workflows/ci.yml/badge.svg)](https://github.com/ljh-sh/macli/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE.txt)

> 最小上下文，最大灵活性 —— 面向 AI agent 的 macOS 系统工具。原生 Apple framework。AI 友好的 JSON/TSV 输出。

**macli** 把 macOS 系统内部能力做成干净的 CLI。SMC 传感器、流式监控、日历/提醒 —— 全都能从 shell 管道或 LLM agent 调用，全是 JSON/TSV。单一 ~400 KB Swift 二进制。无 Python runtime，无 osascript 开销，无 GUI。

用它，当你（或你的 AI agent）需要问 macOS 一些 `system_profiler` / `ioreg` / `osascript` 答不出或答得很烂的问题：*CPU 此刻的核心温度*、*以 1 Hz 把传感器流式喂给 awk*、*今天日历的 JSON*。

镜像：[github.com/ljh-sh/macli](https://github.com/ljh-sh/macli) · [codeberg.org/ljh-sh/macli](https://codeberg.org/ljh-sh/macli)

## 面向 AI agent

最小上下文、最大灵活性 —— 把下面这行 prompt 贴给 Claude Code、Cursor 或任意 agent：

```md
用 `macli` 取 macOS 系统状态（传感器 / 日历 / 提醒）。若未安装：`brew install ljh-sh/cli/macli`。输出为 JSON，检查 `ok` 字段。子命令列表 `macli --help`。
```

## 安装

### Homebrew（推荐）

```sh
brew install ljh-sh/cli/macli
```

或先 tap，再用短名安装：

```sh
brew tap ljh-sh/cli
brew install macli
```

### 直接下载二进制

```sh
curl -L https://github.com/ljh-sh/macli/releases/latest/download/macli-darwin-universal.tar.xz | tar xJ -
sudo mv bin/macli /usr/local/bin/
```

`universal` tarball 是 fat Mach-O（arm64 + x86_64），Apple Silicon 和 Intel Mac 都能跑。

### eget

通过 [x-cmd eget](https://x-cmd.com/install/macli)：

```sh
x eget ljh-sh/macli        # 下载并安装
x eget use ljh-sh/macli    # 装到 ~/.local/bin
```

### 源码编译

需要 Swift 5.10+ / macOS 12+。

```sh
git clone https://github.com/ljh-sh/macli
cd macli
swift build -c release
```

## 一览

```sh
macli smc temp                              # CPU/GPU 温度（JSON）
macli monitor --count 10 --interval 1       # 流式 10 个样本给 awk
macli cal ls                                # 列日历（JSON）
```

输出 schema：成功 `{"ok": true, ...}`，失败 `{"ok": false, "error": "...", "hint": "..."}`。从不沉默。

---

## 路线图

- [x] SMC 传感器快照、流式监控、EventKit
- [ ] 电池健康（`macli battery`）
- [ ] SSD 健康（`macli ssd`）

详情见 [ROADMAP.md](ROADMAP.md)。

---

## SMC 传感器

招牌用例。`macli smc` 读取 macOS 只通过私有 framework 暴露的硬件传感器。

```sh
macli smc temp            # → JSON，所有温度传感器
macli smc temp --tsv      # → TSV 给 awk
macli smc volt            # → PMU 电压轨
macli smc curr            # → PMU 电流轨
macli smc all             # → 全部
```

输出示例：

```json
{
  "ok": true,
  "source": "HID",
  "sensors": [{"name": "PMU tdie1", "value": 57.5, "unit": "°C"}],
  "count": 45
}
```

### 电池与 SSD 健康

macli 也提供独立的电池和 SSD 信息命令，支持 JSON/TSV/plist：

```sh
macli battery             # 循环次数、容量、健康百分比、温度
macli battery --tsv       # 制表符分隔，方便 spreadsheet/awk
macli battery --plist     # 完整原始 AppleSmartBattery IORegistry 快照
macli ssd                 # NVMe 型号、序列号、SMART 状态、TRIM、卷
```

`macli battery` 从 IOKit（`AppleSmartBattery`）读取。

`macli ssd` 解析 `system_profiler SPNVMeDataType`，返回型号、序列号、容量、
SMART 状态、TRIM 支持和卷信息。它**不**解析详细 SMART 日志页，因为 Apple
没有通过公开 API 暴露这些数据。磨损数据（TBW、已用百分比、media errors 等）
请使用 `smartctl`：

```sh
brew install smartmontools
smartctl -a disk0
```

SSD 兼容性：

| 平台 | 基础信息（`macli ssd`） | 详细 SMART |
|---|---|---|
| Apple Silicon 内置 SSD | ✅ | 使用 `smartctl` |
| 外接 Thunderbolt NVMe | ✅ | 使用 `smartctl` |
| USB/SATA 转接盒 | 可能识别为普通存储而非 NVMe | 使用 `smartctl` |

脚本示例：

```sh
# 电池健康低于 80% 时提醒
macli battery | jq -e '.healthPercent < 80' && echo "建议更换电池"

# 记录循环次数和温度
macli battery --tsv | awk -F'\t' '/^cycleCount|^temperature/{print strftime("%Y-%m-%dT%H:%M:%S"), $1, $2}' >> battery.log

# 实时监控系统与电池功耗
macli monitor --metrics battery_power --interval 1
```

### 设计：agent-oriented

macli 遵循 x-cmd 面向 agent 的 CLI 工具设计原则：**最小上下文，最大灵活性**。它故意保持**笨** —— 不算热指数、不聚合、不画图、不判断什么是"过热"。只返回原始传感器值，到此为止。判断交给调用方：

```sh
macli smc temp --tsv | awk -F'\t' '$2 > 80 {print $1, "过热"}'
macli smc temp --tsv | sort -t$'\t' -k2 -n | tail -5    # 最热的 5 个传感器
```

这让 `macli --help` 保持精简（LLM 加载为上下文时省 token）。CLI 就是 API；shell 就是粘合层。

### `smc86` —— Intel legacy，sunset track

`smc86` 是 Intel Mac 对应版本，接口一致。Apple Silicon 上返回空（Intel SMC key 空间被清空）。Intel Mac 完全淘汰后整体移除。

---

## 流式监控

`monitor` 按间隔采样传感器源，流式输出 TSV —— 每行一个样本。单进程，不会每次 poll 都 fork 子进程，不会每次 tick 启 Python 解释器。设计为 `awk` 的长跑管道前级。

```sh
macli monitor --interval 1 --metrics smc_temp,smc_curr
macli monitor --count 10 --interval 0.5 --metrics smc_temp \
  | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print "avg:", sum/n}'
```

参数：

- `--interval N` —— 采样间隔秒（支持小数，默认 1.0）
- `--metrics list` —— 逗号分隔的指标源（默认：全部）
- `--count N` —— 采样 N 次后退出（默认：无限，Ctrl-C 停止）

第一行 header 锁定列顺序；后续行按位置对应。`awk -F'\t'` 是预期的下游。

为什么重要：用 shell 循环（`while; do macli smc temp; sleep 1; done`）每次迭代要付出 ~50ms 二进制启动开销。`monitor` 只付一次，后续采样的边际成本亚毫秒。

---

## EventKit —— 日历 / 日程 / 提醒

`EventKit.framework` 是 Apple 原生的日历和提醒 API。macli 封装给 shell 用 —— JSON 输出，不走 AppleScript。

```sh
macli cal ls                                # 列日历
macli event ls --calendar Work --today      # 今天的日程
macli reminder add --list Shopping "买牛奶"
macli aka set work <calendar-id>            # 给日历 ID 设 alias，方便引用
```

用途：仪表盘、CI 提醒（"下一个会议 5 分钟后开始"）、提醒批量插入、需要稳定日历引用的自动化（`aka`）。

---

## 输出约定

- **快照命令**：默认 JSON 带 `{"ok": bool, ...}`。`--tsv` 切到 awk 友好格式。
- **流式命令**（`monitor`）：只 TSV，第一行 header。
- **错误**：`{"ok": false, "error": "...", "hint": "..."}` —— 从不沉默。

---

## FAQ：安装与权限

### ❓ "无法验证开发者" / "macli cannot be opened because the developer cannot be verified"

macli 是 ad-hoc 签名（没有 Apple Developer ID）。直接下载安装的话，去掉隔离属性：
```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```
Homebrew Formula 通过 `post_install` 自动做。

### ❓ `brew install macli` 报 "trust" 或拒绝加载 Formula

Homebrew 6 对第三方 tap 加了 trust 步骤。跑一次 `brew trust ljh-sh/cli`，再 `brew install ljh-sh/cli/macli`。这是安全特性，不是 bug。

### ❓ 第一次跑 `macli cal ls` / `event ls` / `reminder` 卡几秒

macOS TCC 在弹日历/提醒授权对话框。点系统弹窗授权即可，后续调用瞬间返回。错过弹窗的话，去 系统设置 → 隐私与安全 → 日历（或提醒）里把跑 macli 的终端启用。

## FAQ：SMC —— 是什么，为什么有 macli

### ❓ SMC 是什么？

**System Management Controller（SMC）** 是每台 Mac 内嵌的 Apple 控制器，监控并上报 CPU / GPU / SoC die 温度、PMU 电压轨、PMU 电流轨、风扇转速（Intel Mac）、电池状态。

Intel Mac 上，SMC 通过 `IOKit.framework` 私有 AppleSMC API 查询，使用 4 字符 key（`TCXC`、`TG0P` 等）。Apple Silicon（M1–M4）上同样数据迁移到了 HID sensor hub —— key 完全不同（`PMU tdie1`、`PMU tdie2` 等）且未公开。

参考 —— 把这套梳理出来的项目：
- [dkorunic/iSMC](https://github.com/dkorunic/iSMC) —— Go 写的 CLI，Intel + Apple Silicon 全 key 目录
- [beltex/SMCKit](https://github.com/beltex/SMCKit) —— Swift SMC 库，Intel 时代的经典参考
- [freedomtan/sensors](https://github.com/freedomtan/sensors) —— 早期 Apple Silicon IOKit 探索

### ❓ 为什么不用 Python / PyObjC？

读一个传感器大约要 30 行 C：打开 `AppleSMC` / `AppleHID` IOService，序列化 key，调 `IOConnectCallScalarMethod`，解返回的 struct。key 是私有的，struct 是私有的，调用约定从 Intel 到 Apple Silicon 完全变了。

PyObjC 能调公开 framework，但 SMC 的 key 空间是**私有**的。从 Python 访问意味着 ctypes 级别的 struct 打包，每次 macOS 发布都会坏。没有 `pip install` 的路能跟上 Apple Silicon 的新 key 命名空间。

### ❓ `macli smc86 ...` 在 Apple Silicon 上返回空

正常。`smc86` 查的是 Intel Mac 的 SMC key 空间，Apple Silicon 上被清空了。M 系列 Mac 用 `macli smc`（不是 `smc86`）。

### ❓ macli 跟 iStats / smcFanControl / stats / iSMC / SMCKit 有什么区别？

- [iStats](https://github.com/Chris911/iStats) —— Ruby gem，仅 Intel，最后版本 2018。偏 GUI。
- [smcFanControl](https://github.com/hholtmann/smcFanControl) —— 设最小风扇转速的 macOS app。GUI。
- [stats](https://github.com/exelban/stats) —— macOS 菜单栏仪表盘。GUI。
- [iSMC](https://github.com/dkorunic/iSMC) —— Go CLI。最接近的同类，但 Go runtime 给二进制加 ~5 MB。
- [SMCKit](https://github.com/beltex/SMCKit) —— Swift 库，仅 Intel。无 CLI 流式，无 EventKit。
- **macli** —— Swift CLI，专为 shell 管道和 LLM agent 设计。只 JSON/TSV，无 GUI，无 Ruby/Go runtime，Apple Silicon 一等公民。列表中体积最小（~400 KB stripped）。

## FAQ：EventKit 内部

### ❓ 为什么 `macli cal ls` 比 `osascript` 快？

osascript 要走 AppleScript → Calendar.app RPC 通道 → 权限弹窗。每次冷启动都要加载 AppleScript 组件。macli 直接链 `EventKit.framework`，通过标准 TCC 弹窗请求一次权限，后续调用全在进程内。

### ❓ 为什么用 JSON 不用 AppleScript list 语法？

AppleScript 返回人类可读的字符串如 `{calendar "Work", calendar "Home"}`，解析要 regex 切本地化字符串。JSON 能被 `jq`、python、awk、所有 LLM tool use 接口直接解析，字段名稳定，跟系统语言无关。

### ❓ macli 会改我的日历数据吗？

读命令（`cal ls`、`event ls`）永不触碰状态。写命令（`cal add`、`event add`、`reminder add`）只在你显式调用时跑，参数精确到你传的那些。macli 从不自动同步、不删除、不修改。

## FAQ：兼容性

### ❓ Linux / Windows？

不能。macli 封装的是 Apple 私有 framework（IOKit、HID、EventKit），只在 macOS 上存在。

### ❓ 需要 `sudo` 吗？

不需要。所有子命令以当前用户身份运行。传感器读取走用户态 IOKit / HID API。

### ❓ Apple Silicon vs Intel？

都支持，单一 universal binary。Apple Silicon 用 `macli smc`；Intel 用 `macli smc86`。二进制完全一样，子命令决定走哪条传感器路径。

## FAQ：内部

### ❓ 二进制体积

单架构 ~400 KB（arm64 / x86_64），universal ~830 KB（fat Mach-O），arm64 tar.xz ~110 KB。单一静态二进制 —— 无 Python runtime，无 PyObjC 桥，无 ctypes 层。

### ❓ 代码签名

Ad-hoc。不是 Apple Developer ID（要 $99/年 + notarize，收益边际）。Homebrew Formula 自动去 `com.apple.quarantine`。手动安装跑一次 `xattr -dr`。

### ❓ 构建可复现吗？

基本可复现。

- 前提是 Xcode / LLVM 版本要固定。
- 构建硬化（`SOURCE_DATE_EPOCH`、`ZERO_AR_DATE`、确定性 mtime、RPATH 删除）在 `.x-cmd/release.common.sh` 里处理。

### ❓ 为什么把语音识别（`macli speech recognize`）移除了？

简单说：裸 CLI 用不了 macOS 语音识别。

- `SFSpeechRecognizer` 需要在 `Info.plist` 里声明 `NSSpeechRecognitionUsageDescription`。
- SwiftPM 编译的 CLI 没有 `Info.plist`，TCC 直接拒绝，进程会崩溃。
- 要修就得把 macli 包成 `.app` bundle，发布流程变复杂，不值。
- 直接用 [hear](https://github.com/sveinbjornt/hear) 吧，已签名、已 notarize，专干这个。

### ❓ 为什么不内置聚合 / 告警？

聚合（avg、max、滑动窗口）和告警（阈值 → notify）应该在 awk/jq/python 里做，那里你控制语义。塞进 macli 意味着每个新统计都要加新 flag，`--help` 会膨胀到 LLM 加载为上下文的成本不划算。见上面"设计：agent-oriented"。

---

## 更新日志

版本化发布说明见 [`changelog/`](changelog/)，从 [`v0.0.0.cn.md`](changelog/v0.0.0.cn.md) 开始。

---

## License

Apache 2.0 —— 见 [LICENSE.txt](LICENSE.txt)。

