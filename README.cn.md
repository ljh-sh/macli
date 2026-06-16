# macli

> macOS 原生二进制，专做 shell/python 做不到的事。

**macli** 是一个用 Swift 编译的 CLI，暴露私有 macOS API（HID / IOKit / Speech / EventKit）—— 这些 API 用 Python / shell 调起来要么痛苦要么根本调不动。它**不是**「所有 macOS 工具的大杂烩」，只覆盖 `subprocess` + `osascript` + PyObjC 真的搞不定的部分。

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

### 源码编译

需要 Swift 5.10+ / macOS 12+。

```sh
git clone https://github.com/ljh-sh/macli
cd macli
swift build -c release
.release-artifacts/darwin-arm64/bin/macli --help   # 跑过 .x-cmd/release darwin-arm64 之后
```

## 子命令

### `smc` — Apple Silicon SMC 传感器（HID）

```sh
macli smc temp        # 温度（默认 JSON）
macli smc temp --tsv  # TSV 输出给 awk
macli smc volt        # PMU 电压轨
macli smc curr        # PMU 电流轨
macli smc all         # 全部
```

### `smc86` — Intel SMC 传感器（legacy，sunset track）

跟 `smc` 接口一致，给 Intel Mac 用。Intel Mac 完全淘汰后整体移除。

### `monitor` — 流式 TSV 监控

单进程，所有指标源。设计为 `awk` 下游：

```sh
macli monitor --interval 1 --metrics smc_temp,smc_curr
macli monitor --count 10 --interval 0.5 --metrics smc_temp \
  | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print "avg:", sum/n}'
```

参数：`--interval N`（支持小数秒）、`--metrics list`、`--count N`（采样 N 次后退出）。

### EventKit 家族

```sh
macli cal ls                                # 列日历
macli event ls --calendar Work --today      # 今天的日程
macli reminder add --list Shopping "买牛奶"
macli aka set work <calendar-id>            # 给日历 ID 设 alias
```

### 通知 / TTS / 语音识别

```sh
macli notify send --title "完成" "构建结束"
macli speak text "Hello"
macli speak voices                          # 列出 180 个语音
macli speech recognize audio.m4a            # 转录
macli speech langs                          # 列出 63 种语言
```

## 输出约定

- **快照命令**：默认 JSON 带 `{"ok": bool, ...}`。`--tsv` 切到 awk 友好格式。
- **流式命令**（`monitor`）：只 TSV，第一行 header。
- **错误**：`{"ok": false, "error": "...", "hint": "..."}` —— 从不沉默。

JSON 示例：

```json
{
  "ok": true,
  "source": "HID",
  "sensors": [{"name": "PMU tdie1", "value": 57.5, "unit": "°C"}],
  "count": 45
}
```

## 代码签名

macli 是 **ad-hoc 签名**（不是 Apple Developer ID）。Homebrew Formula 会自动去掉 `com.apple.quarantine`。手动安装的话，跑一下：

```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```

## macli 不是什么

如果某个功能可以用 `subprocess` + 系统 CLI（`pmset` / `system_profiler` / `ioreg` / `airport` / `networksetup`）、`osascript`、或干净的 PyObjC 实现，那它归 [`x-bash/mac`](https://github.com/x-bash/mac) —— 不归 macli。

macli 的范围：私有框架、HID / IOKit / kext 通信、反向工程协议、高频轮询。

## 二进制体积

- 单架构 ~370 KB（arm64 / x86_64）
- universal ~220 KB（fat Mach-O）
- 压缩 ~105 KB（tar.xz）

## License

Apache 2.0 —— 见 [LICENSE.txt](LICENSE.txt)。

## 开发

- [DEV.md](DEV.md) —— 构建 / 测试 / 发布命令
- 开发纲领、roadmap、设计决策放在 [`macli-mneme`](https://github.com/ljh-sh/macli-mneme)（私有）

## 相关项目

- [`x-bash/mac`](https://github.com/x-bash/mac) —— 调用 macli 的脚本层
- [`x-bash/gpu`](https://github.com/x-bash/gpu)、[`x-bash/cpu`](https://github.com/x-bash/cpu)、[`x-bash/display`](https://github.com/x-bash/display) —— macli 正在逐步替换的 ctypes hack
