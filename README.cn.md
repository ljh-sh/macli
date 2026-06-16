# macli

> 面向 AI agent 的 macOS 系统工具。原生 Apple framework。AI 友好的 JSON/TSV 输出。

**macli** 暴露 macOS 上 shell 通常难以触及的部分 —— SMC 传感器、流式监控、日历/提醒、语音识别。单一 Swift 二进制，启动快，输出既给人看也适合管道处理。

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

## 快速上手

```sh
macli smc temp                                    # CPU/GPU 温度（JSON）
macli smc temp --tsv                              # TSV 给 awk
macli monitor --count 10 --interval 0.5 --metrics smc_temp \
  | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print "avg:", sum/n}'
macli cal ls                                      # 列日历
macli notify send --title "完成" "构建结束"
```

## 子命令

### `smc` — Apple Silicon SMC 传感器

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

## 二进制体积

- 单架构 ~370 KB（arm64 / x86_64）
- universal ~220 KB（fat Mach-O）
- 压缩 ~105 KB（tar.xz）

## License

Apache 2.0 —— 见 [LICENSE.txt](LICENSE.txt)。

## 开发

- [DEV.md](DEV.md) —— 构建 / 测试 / 发布命令
- 设计笔记与 issue 跟踪：[`macli-mneme`](https://github.com/ljh-sh/macli-mneme)（私有）
