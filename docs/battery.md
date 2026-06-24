---
layout: default
title: Battery field reference
---

# `macli battery` 字段详解

`macli battery` 读取 macOS IOKit 的 `AppleSmartBattery` 服务，把电池、充电器、电源遥测等数据整理成可直接用 `jq` 处理的 JSON。本文档解释每个字段的来源、单位、参考值和使用场景。

> 当前版本输出的是 **完整/详细模式**；以后会增加 `--detail` 开关，默认输出精简子集，但字段名和结构保持不变。

---

## 与 `ioreg` 的关系

`ioreg -n AppleSmartBattery -r -l` 已经把几乎所有原始数据展示出来了，但它有几点不便：

| 能力 | `ioreg` | `macli battery` |
|---|---|---|
| 输出格式 | XML/Plist 风格文本 | 直接是 JSON |
| 单位换算 | 原始数值，需手动除 100/1000 | 已换算好（温度 °C、电压 V、功率 W 等） |
| 派生指标 | 无 | `healthPercent`、`designWh`、`currentWh` |
| 键名稳定性 | 不同 macOS 版本可能变化 | macli 尽量保持稳定 |
| 脚本友好 | 需要 grep/awk/plist 解析 | `jq` 直接取值 |
| TSV 输出 | 无 | `macli battery --tsv` |
| 与 monitor 集成 | 无 | `macli monitor` 可取电池功率流 |

所以：**`ioreg` 能看原始数据，`macli battery` 帮你把数据变成可编程、可对比、可监控的格式**。两者不是替代关系，而是分层：底层探查用 `ioreg`，脚本/监控/告警用 `macli`。

---

## `serialNumber` 与 `batterySerial` 为什么会不同？

### 来源

| JSON key | IOKit 路径 | 含义 |
|---|---|---|
| `serialNumber` | `AppleSmartBattery.Serial` | 系统层（AppleSmartBattery kext）报告的电池序列号 |
| `batterySerial` | `AppleSmartBattery.BatteryData.Serial` | 电池管理芯片（gas gauge，如 BQ40Z651/BQ20Z451）内部序列号 |

### 为什么会不一样？

这两个序列号来自**不同层级**：

1. **根级 `Serial`** 是 macOS 的 `AppleSmartBattery` 驱动从 SMC/PMU 侧读取或维护的标识，常用于 `system_profiler SPPowerDataType` 和系统设置。
2. **`BatteryData.Serial`** 来自电池包内部的电量计芯片（gas gauge）数据闪存，是电池制造商写入的。

在大多数原装机器上，Apple 会把同一个序列号同步到两个位置，所以它们看起来一样。但在以下场景可能不同：

- **第三方替换电池**：厂商可能只写了 gas gauge 序列号，没同步到根级 `Serial`。
- **不同固件版本**：较新的 Apple Silicon 机器上，根级序列号的编码规则发生变化，导致基于它的“从序列号解析生产日期”方法失效（见 [munkireport/power#26](https://github.com/munkireport/power/issues/26)）。
- **售后维修/翻新电池**：电池包和主板记录的序列号可能不一致。
- **假冒/篡改电池**：常见特征是根级序列号为空或随机，而 `BatteryData.Serial` 与 Apple 正品格式不符（见 [iTech4Mac: How to Spot a Fake Battery](https://www.itech4mac.net/2025/11/how-to-check-battery-cycle-count-on-mac-how-to-spot-a-manipulated-fake-battery/)）。

### 论据

- [munkireport/power#26](https://github.com/munkireport/power/issues/26) 指出：旧方法“从根级 `Serial` 提取 YWWD 生产日期”在新设备上已不可靠，必须改用 `BatteryData.ManufactureDate`。
- 多篇用户报告和电池检测脚本（如 [少数派](https://sspai.com/post/76160)、[anotherdayu](https://anotherdayu.com/2022/3665/)）都同时引用 `BatteryData.Serial` 作为电池身份标识。
- `ioreg` 本身同时暴露两个 `Serial` 键，说明 Apple 认为它们是两个独立字段。

### 怎么用

```sh
# 判断两者是否一致
macli battery | jq '{serialNumber, batterySerial, same: (.serialNumber == .batterySerial)}'

# 怀疑假电池时，优先检查 BatteryData 序列号格式
macli battery | jq '.batterySerial'
```

---

## 适配器电压：`adapter.voltage` 与 `adapter.adapterVoltage`

IOKit 在不同机型/固件里用了两个键表示适配器电压：

| JSON key | IOKit key | 说明 |
|---|---|---|
| `adapter.voltage` | `AdapterDetails.Voltage` | 旧版键名，某些 Intel 机型仍使用 |
| `adapter.adapterVoltage` | `AdapterDetails.AdapterVoltage` | Apple Silicon PD 适配器常用键名 |

macli **两个都读**，所以你的输出里至少有一个存在。如果两个都有，它们应该是同一个值。

```sh
macli battery | jq '.adapter | {voltage, adapterVoltage}'
```

---

## 字段速查表

### 状态

| 字段 | 类型 | IOKit 来源 | 说明 |
|---|---|---|---|
| `ok` | bool | 内部 | 是否成功读到电池 |
| `present` | bool | 内部 | 电池是否在位 |
| `source` | string | 固定 | 恒为 `"IOKit"` |
| `status` | string | 派生 | `"AC"` / `"Battery"` |
| `externalConnected` | bool | `ExternalConnected` | AC 是否插入 |
| `appleRawExternalConnected` | bool | `AppleRawExternalConnected` | 原始 AC 状态 |
| `externalChargeCapable` | bool | `ExternalChargeCapable` | 是否支持外接充电 |
| `isCharging` | bool | `IsCharging` | 是否正在充电 |
| `fullyCharged` | bool | `FullyCharged` | 是否已充满 |
| `builtIn` | bool | `built-in` | 是否为内置电池 |
| `batteryInstalled` | bool | `BatteryInstalled` | 电池是否安装 |
| `atCriticalLevel` | bool | `AtCriticalLevel` | 是否处于临界低电量 |
| `permanentFailureStatus` | int | `PermanentFailureStatus` | 永久故障码，非 0 需警惕 |
| `designCycleCount` | int | `DesignCycleCount9C` | 设计循环寿命，常见 1000 |
| `gasGaugeFirmwareVersion` | int | `GasGaugeFirmwareVersion` | 电量计固件版本 |

### 容量与能量

| 字段 | 单位 | 说明 |
|---|---|---|
| `designCapacity` | mAh | 设计容量 |
| `maxCapacity` | mAh | 当前最大可用容量 |
| `currentCapacity` | mAh | 当前剩余容量 |
| `nominalChargeCapacity` | mAh | gas gauge 标称容量 |
| `absoluteCapacity` | mAh | 绝对容量 |
| `packReserve` | mAh | 保留容量 |
| `healthPercent` | % | `maxCapacity / designCapacity * 100` |
| `designWh` | Wh | 设计能量 |
| `currentWh` | Wh | 当前剩余能量 |

### 电压 / 电流

| 字段 | 单位 | 说明 |
|---|---|---|
| `voltage` | mV | 电池包电压 |
| `amperage` | mA | 平均电流 |
| `instantAmperage` | mA | 瞬时电流 |
| `appleRawBatteryVoltage` | mV | 原始电池电压 |
| `bootVoltage` | mV | 启动时电压 |

### 电量百分比

| 字段 | 说明 |
|---|---|
| `stateOfCharge` | 系统层电量百分比（`CurrentCapacity`） |
| `gaugeStateOfCharge` | gas gauge 电量百分比（`BatteryData.StateOfCharge`） |

两者通常接近，差 1% 属于正常。

### 温度

| 字段 | 单位 | 说明 |
|---|---|---|
| `temperature` | °C | 物理传感器温度 |
| `virtualTemperature` | °C | 电池模型估算温度 |

### 时间估算

| 字段 | 单位 | 说明 |
|---|---|---|
| `timeRemaining` | 分钟 | 系统估算剩余时间 |
| `avgTimeToEmpty` | 分钟 | 基于平均耗电的放空时间 |
| `avgTimeToFull` | 分钟 | 基于平均充电的充满时间 |

`65535` 表示无效/未知（常见于接 AC 未充电时）。

### 识别信息

| 字段 | 说明 |
|---|---|
| `serialNumber` | 系统层序列号 |
| `batterySerial` | gas gauge 序列号 |
| `deviceName` | 电量计芯片型号，如 `bq40z651` |
| `manufactureDate` | 出厂日期码（芯片原生格式） |
| `manufacturerData` | hex | 制造商原始数据 |

### 电芯数据

| 字段 | 单位 | 说明 |
|---|---|---|
| `cellVoltages` | V | 每个电芯电压 |
| `qmax` | mAh | 每个电芯最大化学容量 |
| `cellWom` | - | cell wake-on-motion 标志 |
| `presentDOD` | - | 当前放电深度 |
| `dod0` | - | 初始 DOD 校准值 |
| `weightedRa` | mΩ | 加权内阻 |
| `cellCurrentAccumulator` | - | 电芯电流累积器 |

### 电池数据诊断

| 字段 | 说明 |
|---|---|
| `batteryDataFlags` | BatteryData 状态标志 |
| `gaugeFlagRaw` | gas gauge 原始标志 |
| `miscStatus` |  miscellaneous 状态 |
| `itMiscStatus` | IT misc 状态 |
| `chemID` | 化学 ID |
| `algoChemID` | 算法化学 ID |
| `fccComp1` / `fccComp2` | 满充补偿值 |
| `resScale` / `rss` / `iss` | 内阻/缩放相关 |
| `dataFlashWriteCount` | 数据闪存写入次数 |
| `batteryHealthMetric` | 电池健康度指标 |
| `chemicalWeightedRa` | 化学加权内阻 |
| `pmuConfigured` | PMU 配置值 |
| `soc1Voltage` | SoC=1% 时电压 |
| `qmaxDisqualificationReason` | Qmax 失效原因码 |
| `simRate` / `idealCRate` | 仿真/理想 C-rate |
| `packCurrentAccumulator` | 包电流累积器 |
| `packCurrentAccumulatorCount` | 累积计数 |
| `filteredCurrent` | 滤波后电流 |
| `dateOfFirstUse` | 首次使用日期码 |
| `gaugeCycleCount` | gas gauge 计循环数 |
| `batteryState` | hex | gas gauge 状态字节 |
| `mfgData` | hex | 制造商数据 |

### 适配器

| 字段 | 说明 |
|---|---|
| `adapter.watts` | 额定功率（W） |
| `adapter.current` | 额定电流（mA） |
| `adapter.voltage` | 额定电压（mV，旧键名） |
| `adapter.adapterVoltage` | 额定电压（mV，新键名） |
| `adapter.description` | 描述，如 `"pd charger"` |
| `adapter.isWireless` | 是否无线充电器 |
| `adapter.adapterID` | 适配器 ID |
| `adapter.familyCode` | 家族码 |
| `adapter.adapterPowerTier` | 功率等级 |
| `adapter.usbHvcHvcIndex` | USB HVC 索引 |
| `adapter.pmuConfiguration` | PMU 配置 |
| `adapter.usbHvcMenu` | PDO 档位列表 |
| `inputPower` | `adapter.watts` 的平铺副本 |
| `rawAdapterDetails` | 每个 USB-C 口的原始适配器信息 |

### 充电器

| 字段 | 说明 |
|---|---|
| `charger.voltage` | 当前充电电压（mV） |
| `charger.current` | 当前充电电流限制（mA） |
| `charger.status` | hex | 充电器状态字节 |
| `charger.vacVoltageLimit` | VAC 电压限制 |
| `charger.notChargingReason` | 不充电原因码 |
| `charger.slowChargingReason` | 慢充原因码 |
| `charger.resetCounter` | 充电器复位计数 |
| `charger.chargerID` | 充电器 ID |
| `charger.timeChargingThermallyLimited` | 热限制充电时长 |
| `charger.inhibitReason` | 抑制原因码 |

### 系统电源遥测

| 字段 | 单位 | 说明 |
|---|---|---|
| `systemPower` | W | 系统总功耗 |
| `batteryPower` | W | 电池输出功率 |
| `systemVoltageIn` | mV | 系统输入电压 |
| `systemCurrentIn` | mA | 系统输入电流 |
| `systemLoad` | mW | 系统负载 |
| `wallEnergyEstimate` | - | 墙面能量估算 |
| `systemEnergyConsumed` | - | 系统消耗能量 |
| `accumulatedSystemLoad` | - | 累积系统负载 |
| `accumulatedSystemEnergyConsumed` | - | 累积系统能耗 |
| `accumulatedWallEnergyEstimate` | - | 累积墙面能量估算 |
| `accumulatedBatteryPower` | - | 累积电池功率 |
| `accumulatedSystemPowerIn` | - | 累积系统输入功率 |
| `accumulatedBatteryDischarge` | - | 累积电池放电量 |
| `adapterEfficiencyLoss` | - | 适配器效率损耗 |
| `accumulatedAdapterEfficiencyLoss` | - | 累积适配器效率损耗 |
| `powerTelemetryErrorCount` | - | 遥测错误计数 |
| `systemPowerInAccumulatorCount` | - | 系统输入功率累积计数 |
| `systemLoadAccumulatorCount` | - | 系统负载累积计数 |
| `adapterEfficiencyLossAccumulatorCount` | - | 效率损耗累积计数 |
| `batteryPowerAccumulatorCount` | - | 电池功率累积计数 |
| `batteryDischargeAccumulatorCount` | - | 电池放电累积计数 |

### USB-C PD 与端口诊断

| 字段 | 说明 |
|---|---|
| `fedDetails` | 每个 USB-C 口连接的 PD 设备信息 |
| `portControllerInfo` | 每个 USB-C 口控制器诊断 |

### 生命周期数据

| 字段 | 说明 |
|---|---|
| `lifetimeData.updateTime` | 数据更新时间戳 |
| `lifetimeData.totalOperatingTime` | 总运行时间 |
| `lifetimeData.temperatureSamples` | 温度采样次数 |
| `lifetimeData.averageTemperature` | 平均温度（0.1°C） |
| `lifetimeData.minimumTemperature` | 最低温度（0.1°C） |
| `lifetimeData.maximumTemperature` | 最高温度（0.1°C） |
| `lifetimeData.maximumDischargeCurrent` | 最大放电电流 |
| `lifetimeData.maximumChargeCurrent` | 最大充电电流 |
| `lifetimeData.minimumPackVoltage` | 最小包电压 |
| `lifetimeData.maximumPackVoltage` | 最大包电压 |
| `lifetimeData.cycleCountLastQmax` | 上次 Qmax 校准时的循环数 |
| `lifetimeData.resistanceUpdatedDisabledCount` | 内阻更新禁用计数 |
| `lifetimeData.rdisCnt` | RDIS 计数 |

---

## 使用示例

```sh
# 只看最关心的状态
macli battery | jq '{status, stateOfCharge, currentCapacity, maxCapacity, healthPercent, cycleCount, temperature}'

# 判断健康度是否低于 80%
macli battery | jq -e '.healthPercent < 80' && echo "consider replacement"

# 计算真实充电功率（如果正在充电）
macli battery | jq '{watts: (.charger.voltage * .charger.current / 1000000)}'

# 检查两个序列号是否一致
macli battery | jq '{serialNumber, batterySerial, same: (.serialNumber == .batterySerial)}'

# 查看每个 USB-C 口接了什么
macli battery | jq '.fedDetails'

# 查看 PDO 供电档位
macli battery | jq '.adapter.usbHvcMenu'

# 导出为 TSV 在表格里打开
macli battery --tsv > battery.tsv
```

---

## 补充字段（进一步覆盖 ioreg）

以下字段是为了让 `macli battery` 成为 `ioreg` 的超集而补充的：

| 字段 | 来源 | 说明 |
|---|---|---|
| `batteryCellDisconnectCount` | `BatteryCellDisconnectCount` | 电芯断开次数 |
| `skipperNEIgnoreAtCritical` | `SkipperNEIgnoreAtCritical` | 临界电量忽略标志 |
| `maxCapacityPercent` | `MaxCapacity` | 系统层最大容量百分比（常为 100） |
| `chargerConfiguration` | `ChargerConfiguration` | 充电器配置值 |
| `carrierMode` | `CarrierMode` | 载体模式参数（低/高电压阈值、状态） |
| `deadBatteryBootData` | `DeadBatteryBootData` | 没电时启动记录的 payload |
| `ocvData` | `OCVData` | 开路电压数据（通常为空） |
| `lpemData` | `LPEMData` | LPEM 数据（通常为空） |
| `batteryRsenseOpenCount` | `BatteryData.BatteryRsenseOpenCount` | 电流采样电阻开路计数 |
| `cellCurrentAccumulatorCount` | `BatteryData.CellCurrentAccumulatorCount` | 电芯电流累积计数 |
| `currentSenseMonitorStatus` | `BatteryData.CurrentSenseMonitorStatus` | 电流采样监控状态 |
| `dod0AtQualifiedQmax` | `BatteryData.Dod0AtQualifiedQmax` | Qmax 合格时的 DOD0 |
| `ra00` ~ `ra14` | `BatteryData.Ra00` ~ `Ra14` | 各温度点内阻表（mΩ） |
| `batteryDataSystemPower` | `BatteryData.SystemPower` | gas gauge 原始系统功率 |
| `batteryDataAdapterPower` | `BatteryData.AdapterPower` | gas gauge 原始适配器功率 |

### 故意不重复输出的字段

以下字段在 ioreg 里同时出现在根级和 `BatteryData` 里，macli 已经在根级输出，所以不再在 `BatteryData` 下重复：

| ioreg 键 | macli 已输出为 |
|---|---|
| `BatteryData.DesignCapacity` | `designCapacity` |
| `BatteryData.MaxCapacity` | `maxCapacityPercent` |
| `BatteryData.Voltage` | `voltage` |
| `BatteryData.CycleCount` | `gaugeCycleCount`（同时根级有 `cycleCount`） |

### 跳过的字段

以下字段是 IO 元数据或大块二进制 blob，macli 故意不输出：

- `IOGeneralInterest`、`IOObjectClass`、`IORegistryEntryID` 等 IO 元数据
- `BatteryData.RaTableRaw`、`BatteryData.iMaxAndSocSmoothTable`、`BatteryData.MfgData`（已在 `mfgData` 输出 hex）
- `BatteryData.BatteryState`（已在 `batteryState` 输出 hex）
- `ChargerData.ChargerStatus`（已在 `charger.status` 输出 hex）
- `LifetimeData.Raw`、`LifetimeData.TimeAtHighSoc` 等二进制时间序列
- `PortControllerInfo` 里的 `PortControllerEvtBuffer` 等大块原始 buffer

---

## 数据布局说明

`macli battery` 的输出布局遵循以下原则：

1. **兼容优先**：所有已有的顶层字段（`designCapacity`、`maxCapacity`、`healthPercent` 等）位置和名字不变。
2. **一个 IOKit key 尽量对应一个 JSON key**：新增字段不合并、不重新分组。
3. **只有多实例或结构复杂的数据才嵌套**：
   - `adapter` 是对象，因为适配器信息包含多个子字段。
   - `rawAdapterDetails`、`fedDetails`、`portControllerInfo` 是数组，因为 macOS 按 USB-C 口提供多份数据。
   - `lifetimeData`、`carrierMode`、`deadBatteryBootData` 是对象，因为它们在 IOKit 里本身就是嵌套字典。
4. **命名风格**：
   - 顶层历史字段和新增标量字段使用 camelCase。
   - 嵌套对象/数组内部保留 IOKit 原始 PascalCase 键名，避免 invent mapping。

**优点**：`jq '.healthPercent'` 直接取值，不破坏旧脚本。  
**代价**：顶层键很多（约 150 个），第一眼会比较 overwhelm。后续 `--detail` 开关会把默认输出精简到 15~20 个常用字段。

---

## 如何用 ioreg 查看 macli 未输出的字段

macli 为了兼容、体积和可读性，跳过了 IO 元数据和大块二进制 blob。如果你需要这些原始字段，直接用 `ioreg`：

```sh
# 1. 查看完整原始快照
ioreg -n AppleSmartBattery -r -l

# 2. 保存为 plist 并用 plutil 查看（更结构化）
ioreg -n AppleSmartBattery -r -a -l > /tmp/battery.plist
plutil -p /tmp/battery.plist

# 3. 只看被 macli 跳过的二进制/大块字段
ioreg -n AppleSmartBattery -r -l | \
  grep -E -A2 'RaTableRaw|iMaxAndSocSmoothTable|"BatteryState"|"ChargerStatus"|TimeAtHighSoc|"Raw"|PortControllerEvtBuffer'

# 4. 查看 BatteryData 里被 macli 故意去重的字段
#    （它们已在根级输出为 designCapacity / maxCapacityPercent / voltage / gaugeCycleCount）
ioreg -n AppleSmartBattery -r -l | \
  grep -A40 '"BatteryData"' | \
  grep -E 'DesignCapacity|MaxCapacity|Voltage|CycleCount'

# 5. 查看所有 IO 元数据（IOObjectClass、IORegistryEntryID 等）
ioreg -n AppleSmartBattery -r -l | grep -E 'IO(Object|Registry|Report|Service)'
```

说明：

- `RaTableRaw`、`iMaxAndSocSmoothTable` 是电池算法内部表格，对人类可读性极低。
- `BatteryState`、`ChargerStatus`、`MfgData`、`ManufacturerData` macli 已输出 hex 字符串版本。
- `LifetimeData.Raw`、`TimeAtHighSoc` 是时间序列二进制数据。
- `PortControllerEvtBuffer` 是每个 USB-C 口的原始事件 buffer，通常 512 字节左右。

---

## 常见问题

**Q：输出字段这么多，是不是 bug？**
A：不是。当前是完整模式，所有 IOKit 里有价值的数据都flatten/保留了出来。后续 `--detail` 开关会让默认输出变精简。

**Q：`nominalChargeCapacity` 为什么比 `designCapacity` 大？**
A：它是 gas gauge 的标称校准值，会漂移，略大于设计值是正常的。

**Q：`timeRemaining` 为什么是 65535？**
A：接电源且未充电时无法估算，Apple 用 65535 表示无效。

**Q：`batterySerial` 和 `serialNumber` 一样代表没问题吗？**
A：在原装机器上通常一样。如果你怀疑电池被更换或篡改，重点看 `batterySerial` 格式是否符合 Apple 正品规律，以及 `manufactureDate` 是否与机器年龄匹配。

**Q：为什么 `ioreg` 就够了还要用 macli？**
A：`ioreg` 是原始探查工具；`macli battery` 把它变成结构化的 JSON、做了单位换算、加了派生指标，并且能被脚本和 `macli monitor` 复用。
