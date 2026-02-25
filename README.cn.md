# macli

macOS 系统工具 CLI，支持 JSON/YAML 输出，零依赖。

## 安装

```bash
swift build -c release
cp .build/release/macli /usr/local/bin/
```

## 命令

### cal - 日历管理

```bash
macli cal ls                  # 列出所有日历
macli cal add --name 工作     # 创建日历
macli cal rm --name 工作      # 删除日历
```

### event - 日历事件

```bash
macli event ls --calendar 工作                    # 列出事件
macli event add --calendar 工作 --title 会议 \
                --start "2024-01-15 10:00" \
                --end "2024-01-15 11:00"          # 创建事件
macli event rm --id <事件ID>                      # 删除事件
```

### reminder - 提醒事项

```bash
macli reminder ls             # 列出提醒列表
macli reminder add --name 购物  # 创建列表
```

### notify - 系统通知

```bash
macli notify --title "提醒" --body "任务完成"
macli notify --title "测试" --sound    # 带提示音
```

### location - 当前位置

```bash
macli location                # 获取当前坐标
```

### speak - 文本转语音

```bash
macli speak "你好世界"        # 朗读文本
```

### speech - 语音识别

```bash
macli speech recognize --file audio.m4a  # 转录音频
```

---

### smc - Apple Silicon SMC 传感器 (M1/M2/M3/M4/M5)

```bash
macli smc temp        # 温度传感器 (JSON)
macli smc temp --tsv  # 温度传感器 (TSV)
macli smc volt        # 电压传感器
macli smc curr        # 电流传感器
macli smc all         # 所有传感器
```

**子命令:** `temp`, `volt`, `curr`, `power`, `fans`, `batt`, `all`

**选项:** `--tsv` - 输出 TSV 格式而非 JSON

### smc86 - Intel SMC 传感器 (旧版 Mac)

```bash
macli smc86 temp      # 温度传感器
macli smc86 fans      # 风扇转速
macli smc86 batt      # 电池状态
macli smc86 all       # 所有传感器
```

## 输出格式

### JSON (默认)

```json
{
  "ok": true,
  "source": "HID",
  "sensors": [
    {"name": "PMU tdie1", "value": 57.5, "unit": "°C"}
  ],
  "count": 45
}
```

### TSV (--tsv)

```
name    value   unit
PMU tdie1       57.5    °C
```

## 二进制体积

- 二进制: ~580KB
- 压缩 (tar.xz): ~136KB

## 许可证

Apache 2.0

---

开发文档请参阅 [DEV.md](DEV.md)
