# macli

> 面向 AI agent 的 macOS 系统工具。原生 Apple framework。AI 友好的 JSON/TSV 输出。

**macli** 是一个 Swift 编译的小 CLI，通过你 GUI 应用同样的原生 Apple framework 暴露 macOS 系统状态 —— SMC 传感器、流式监控、日历/提醒、语音。单一二进制，JSON/TSV 输出，为 LLM agent 和 shell 脚本同样设计。

镜像：[github.com/ljh-sh/macli](https://github.com/ljh-sh/macli) · [codeberg.org/ljh-sh/macli](https://codeberg.org/ljh-sh/macli)

## 面向 AI agent

一句话 prompt —— 直接粘贴到 Claude Code、Cursor 或任意 agent 的 system prompt：

```md
若 `macli` 未安装则先装：`brew install ljh-sh/macli/macli`。用它取 macOS 系统状态（传感器 / 日历 / 语音 / 通知）。输出为 JSON，检查 `ok` 字段。子命令列表 `macli --help`。
```

## 安装

### Homebrew（推荐）

```sh
brew tap ljh-sh/macli
brew install macli
```

或一行：

```sh
brew install ljh-sh/macli/macli
```

### 直接下载二进制

从 [Releases](https://github.com/ljh-sh/macli/releases) 下载：

```sh
curl -L https://github.com/ljh-sh/macli/releases/latest/download/macli-darwin-universal.tar.xz | tar xJ -
sudo mv bin/macli /usr/local/bin/
```

`universal` tarball 是 fat Mach-O（arm64 + x86_64），Apple Silicon 和 Intel Mac 都能跑。

### eget

通过 [x-cmd eget](https://x-cmd.com/install/macli) —— 下载对应的 release 产物并放到 PATH：

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
.release-artifacts/darwin-arm64/bin/macli --help   # 跑过 .x-cmd/release darwin-arm64 之后
```

---

## SMC 传感器 —— 核心

macli 的招牌用例。`macli smc` 读取 macOS 只通过私有 framework 暴露的硬件传感器。

### SMC 是什么？

**System Management Controller（SMC）** 是每台 Mac 内嵌的 Apple 控制器，监控并上报：

- CPU / GPU / SoC die 温度
- PMU 电压轨（`PPPW`、`PCPC` 等）
- PMU 电流轨
- 风扇转速（Intel Mac）
- 电池状态和功耗

Intel Mac 上，SMC 通过 `IOKit.framework` 私有 AppleSMC API 查询，使用 4 字符 key（`TCXC`、`TG0P` 等）。Apple Silicon（M1–M4）上同样数据迁移到了 HID sensor hub —— key 完全不同（`PMU tdie1`、`PMU tdie2` 等）且未公开。

参考 —— 把这套梳理出来的项目：

- [dkorunic/iSMC](https://github.com/dkorunic/iSMC) —— Go 写的 CLI，Intel + Apple Silicon 全 key 目录
- [beltex/SMCKit](https://github.com/beltex/SMCKit) —— Swift SMC 库，Intel 时代的经典参考
- [freedomtan/sensors](https://github.com/freedomtan/sensors) —— 早期 Apple Silicon IOKit 探索

### 为什么不用 Python / PyObjC？

读一个传感器大约要 30 行 C：打开 `AppleSMC` / `AppleHID` IOService，序列化 key，调 `IOConnectCallScalarMethod`，解返回的 struct。key 是私有的，struct 是私有的，调用约定从 Intel 到 Apple Silicon 完全变了。

PyObjC 能调公开 framework，但 SMC 的 key 空间是**私有**的。从 Python 访问意味着 ctypes 级别的 struct 打包，每次 macOS 发布都会坏。没有 `pip install` 的路可走 —— 现有的 Python 尝试（[iStats](https://github.com/Chris911/iStats) 等）最终都烂掉了。

### 为什么用 macli？

macli 用一个链接到原生 IOKit / HID framework 的 Swift 二进制封装同样的私有 API。二进制小（~400 KB），启动 ~50ms，返回结构化输出：

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

### 设计：agent-oriented

macli 故意保持**笨**。它**不**做：

- 计算"体感温度"之类的派生指标
- 聚合、平均、滑动窗口
- 画图、上色、进度条
- 判断什么是"过热"或"异常"

只返回原始传感器值，到此为止。判断交给调用方 —— 这才是重点。awk、jq、python 处理这些本来就更擅长：

```sh
macli smc temp --tsv | awk -F'\t' '$2 > 80 {print $1, "过热"}'
macli smc temp --tsv | sort -t$'\t' -k2 -n | tail -5    # 最热的 5 个传感器
```

这让 `macli --help` 保持精简（LLM 加载为上下文时省 token），让你能用你已经熟悉的工具。CLI 就是 API；shell 就是粘合层。

### `smc86` —— Intel legacy，sunset track

`smc86` 是 Intel Mac 对应版本，接口一致。Intel Mac 完全淘汰后整体移除。

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

为什么重要：用 shell 循环轮询（`while; do macli smc temp; sleep 1; done`）每次迭代要付出 ~50ms 二进制启动开销。`monitor` 只付一次，后续采样的边际成本亚毫秒。

---

## EventKit —— 日历 / 日程 / 提醒

`EventKit.framework` 是 Apple 原生的日历和提醒 API。macli 封装给 shell 用 —— JSON 输出，不走 AppleScript。

```sh
macli cal ls                                # 列日历
macli event ls --calendar Work --today      # 今天的日程
macli reminder add --list Shopping "买牛奶"
macli aka set work <calendar-id>            # 给日历 ID 设 alias，方便引用
```

为什么不用 `osascript`？

- **osascript 要走 AppleScript + Calendar.app** —— 冷启动要加载 AppleScript 组件、Calendar.app RPC 通道、权限弹窗。首次调用经常卡几秒等用户授权。
- **macli 直接链 `EventKit.framework`**，通过标准 macOS TCC 弹窗请求一次权限。后续调用全在进程内。
- **JSON 输出**，不是 AppleScript 的 list 语法 —— `jq` 直接能解析，不用切字符串。

用途：仪表盘、CI 提醒（"下一个会议 5 分钟后开始"）、提醒批量插入、需要稳定日历引用的自动化（`aka`）。

---

## 通知 / TTS / 语音识别

```sh
macli notify send --title "完成" "构建结束"
macli speak text "Hello"
macli speak voices                          # 列出 180 个语音
macli speech recognize audio.m4a            # 通过 Speech.framework 转录
macli speech langs                          # 列出 63 种语言
```

覆盖 `osascript -e 'display notification'` / `say` 能做但脚本化很别扭的场景（语音枚举、音频文件转录、批量发送）。`macli speech recognize` 封装 `Speech.framework`，本地设备转录 —— 无 API key，不上云。

---

## 输出约定

- **快照命令**：默认 JSON 带 `{"ok": bool, ...}`。`--tsv` 切到 awk 友好格式。
- **流式命令**（`monitor`）：只 TSV，第一行 header。
- **错误**：`{"ok": false, "error": "...", "hint": "..."}` —— 从不沉默。

## 代码签名

macli 是 **ad-hoc 签名**（不是 Apple Developer ID）。Homebrew Formula 会自动去掉 `com.apple.quarantine`。手动安装的话，跑一下：

```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```

## 二进制体积

- 单架构 ~400 KB（arm64 / x86_64）
- universal ~830 KB（fat Mach-O，arm64 + x86_64）
- 压缩 ~110 KB arm64 tar.xz / ~130 KB x64 tar.xz / ~222 KB universal tar.xz

单一静态二进制。无 Python runtime，无 PyObjC 桥，无 ctypes 层。

## License

Apache 2.0 —— 见 [LICENSE.txt](LICENSE.txt)。

## 开发

- [DEV.md](DEV.md) —— 构建 / 测试 / 发布命令
- 设计笔记与 issue 跟踪：[`macli-mneme`](https://github.com/ljh-sh/macli-mneme)（私有）
