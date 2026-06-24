---
layout: default
title: Battery field reference and power-user guide
---

# `macli battery` 字段详解与诊断手册

`macli battery` 读取 macOS IOKit 的 `AppleSmartBattery` 服务，把电池、充电器、电源遥测等数据整理成可直接用 `jq` 处理的 JSON。它是 `ioreg -n AppleSmartBattery -r` 的**严格超集**：除了 IO 元数据，几乎所有标量、数组、嵌套对象都被保留，并且增加了单位换算、派生指标和二进制 blob 解码。

> 当前版本输出的是 **完整/详细模式**；以后会增加 `--detail` 开关，默认输出精简子集，但字段名和结构保持不变。

---

## 30 秒上手

```sh
# 核心状态
macli battery | jq '{status, stateOfCharge, healthPercent, cycleCount, temperature}'

# 功率流（电池输出功率、系统功耗、输入功率、瞬时功率）
macli battery | jq '{instantPowerWatts, batteryPower, systemPower, inputPower}'

# 电芯平衡（delta > 0.05 V 要留意）
macli battery | jq '{cellVoltages, cellVoltageDelta}'

# 解码后的每电芯内阻表
macli battery | jq '.raTableRaw'

# 导出 TSV 给 Excel / Numbers / R
macli battery --tsv > battery.tsv
```

---

## 为什么用 `macli battery` 而不是 `ioreg`？

`ioreg -n AppleSmartBattery -r -l` 已经把几乎所有原始数据展示出来了，但它有几点不便：

| 能力 | `ioreg` | `macli battery` |
|---|---|---|
| 输出格式 | XML/Plist 风格文本 | 直接是 JSON |
| 单位换算 | 原始数值，需手动除 100/1000 | 已换算好（温度 °C、电压 V、功率 W 等） |
| 派生指标 | 无 | `healthPercent`、`designWh`、`currentWh`、`cellVoltageDelta`、`instantPowerWatts` |
| 二进制 blob | `RaTableRaw`、`BatteryState` 等是原始 `<...>` 数据 | `raTableRaw`、`batteryStateBytes`、`mfgDataAscii` 等已解码 |
| 键名稳定性 | 不同 macOS 版本可能变化 | macli 尽量保持稳定 |
| 脚本友好 | 需要 grep/awk/plist 解析 | `jq` 直接取值 |
| TSV 输出 | 无 | `macli battery --tsv` |
| 与 monitor 集成 | 无 | `macli monitor` 可取电池功率流 |

所以：**`ioreg` 能看原始数据，`macli battery` 帮你把数据变成可编程、可对比、可监控的格式**。两者不是替代关系，而是分层：底层探查用 `ioreg`，脚本/监控/告警用 `macli`。

### 与 `system_profiler SPPowerDataType` 的对比

`system_profiler` 只给出人类可读的摘要（循环次数、状态、最大容量百分比）。`macli battery` 则提供**原始遥测**：每个电芯电压、充电器状态、PD 适配器档位、电量计内部标志、生命周期数据等。

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

## 诊断脚本手册

下面这些脚本可以直接复制使用。它们展示了 `macli battery` 如何超越“查看信息”，变成真正的诊断工具。

### 1. 健康度与寿命

```sh
# 健康度低于 80% 时报警
macli battery | jq -e '.healthPercent < 80' && echo "考虑更换电池"

# 循环次数 + 设计寿命，算剩余寿命比例
macli battery | jq '{cycleCount, designCycleCount, lifeUsedPercent: (.cycleCount / .designCycleCount * 100)}'

# 温度换算成华氏度
macli battery | jq '{celsius: .temperature, fahrenheit: (.temperature * 9 / 5 + 32)}'
```

### 2. 功率与充电

```sh
# 当前系统/电池/输入功率全景
macli battery | jq '{instantPowerWatts, batteryPower, systemPower, inputPower, chargerPower: .charger.powerWatts}'

# 判断是否在“慢充”或“不充电”
macli battery | jq '{externalConnected, isCharging, fullyCharged, notChargingReason: .charger.notChargingReason, slowChargingReason: .charger.slowChargingReason}'

# 估算从当前电量到满电需要多少 Wh
macli battery | jq '{remainingWh: (.estimatedFullChargeWh - .currentWh), estimatedFullChargeWh, currentWh}'
```

### 3. 电芯平衡与内阻

```sh
# 电芯电压差
macli battery | jq '{cellVoltages, cellVoltageDelta}'

# 电压差大于 0.05 V 时高亮
macli battery | jq -e '.cellVoltageDelta > 0.05' && echo "电芯不平衡，建议校准或检查"

# 查看加权内阻（mΩ）
macli battery | jq '{weightedRa, chemicalWeightedRa, resScale, rss, iss}'

# 把 raTableRaw 画成每个电芯的电阻表
macli battery | jq '.raTableRaw | to_entries[] | {cell: .key, table: .value}'
```

### 4. 适配器与 USB-C PD

```sh
# 当前适配器能力
macli battery | jq '.adapter | {watts, voltage, current, description, isWireless}'

# PDO 档位（适配器支持的电压/电流组合）
macli battery | jq '.adapter.usbHvcMenu'

# 每个 USB-C 口接了什么设备
macli battery | jq '.fedDetails | map({vendorID, productID, externalConnected, remainingCapacity})'
```

### 5. 时间序列与监控

```sh
# 每隔 5 秒记录一条 CSV
while true; do
  macli battery | jq -r '[now, .stateOfCharge, .temperature, .instantPowerWatts, .cellVoltageDelta] | @csv'
  sleep 5
done >> battery.csv

# 用 macli monitor 流式监控电池功率（每秒一个样本，共 60 个）
macli monitor --metric battery_power --interval 1 --count 60

# 计算过去 N 次采样的平均功耗
macli monitor --metric battery_power --interval 1 --count 60 | awk -F'\t' 'NR>1 {sum+=$2; n++} END {print "avg:", sum/n, "W"}'
```

### 6. 可疑电池 / 身份核对

```sh
# 两个序列号是否一致
macli battery | jq '{serialNumber, batterySerial, same: (.serialNumber == .batterySerial)}'

# 制造商数据里的 ASCII 片段
macli battery | jq '{mfgDataAscii, manufacturerDataAscii, deviceName, manufactureDate}'

# 一次性输出所有可用于判断电池是否原生的字段
macli battery | jq '{serialNumber, batterySerial, deviceName, manufactureDate, cycleCount, designCycleCount, mfgDataAscii}'
```

---

## 二进制字段解析说明

`ioreg` 里有些字段是 `NSData` blob，`macli battery` 对它们做了不同处理：

| 字段 | 原始 IOKit 键 | macli 处理方式 | 说明 |
|---|---|---|---|
| `raTableRaw` | `BatteryData.RaTableRaw` | 解析为每电芯 `uint16` 数组 | 电量计内阻表，字节序为 big-endian |
| `batteryState` / `batteryStateBytes` | `BatteryData.BatteryState` | hex 字符串 + uint8 数组 | gas gauge 扩展状态字节 |
| `mfgData` / `mfgDataAscii` | `BatteryData.MfgData` | hex 字符串 + 可打印 ASCII | 制造商原始数据，常含产线代码 |
| `manufacturerData` / `manufacturerDataAscii` | `AppleSmartBattery.ManufacturerData` | hex 字符串 + 可打印 ASCII | 顶层制造商数据 |
| `charger.status` / `charger.statusBytes` | `ChargerData.ChargerStatus` | hex 字符串 + uint8 数组 | 充电器 IC 状态 |
| `iMaxAndSocSmoothTable` | `BatteryData.iMaxAndSocSmoothTable` | hex 字符串 | 电流-电量平滑表，通常全 0 |
| — | `LifetimeData.Raw` / `TimeAtHighSoc` | 跳过 | Apple 电量计私有生命周期日志，无公开格式 |
| — | `PortControllerEvtBuffer` | 跳过 | USB-PD 控制器原始事件 buffer，无公开格式 |

### 关于 `BatteryState` 和 `ChargerStatus` 的 bit 含义

SBS（Smart Battery System）规范定义了标准寄存器：

- `BatteryStatus(0x16)`：2 字节，包含 `DISCHARGING`、`FULLY_CHARGED`、`TERMINATE_CHARGE_ALARM` 等标志。
- `ChargingStatus(0x55)`：2 字节，包含 `FCHG`、`PULSEOFF` 等标志。

但 Apple 在 `BatteryData.BatteryState` 里放的是**扩展状态 blob**（常见 16~17 字节），`ChargerData.ChargerStatus` 新版本也是 `NSData`。前两个字节可能对应 SBS 标志，其余字节布局未公开。`macli battery` 只负责把它们以 hex/bytes 形式暴露出来，**不推测未验证的 bit 语义**。

### 关于 `RaTableRaw`

每个电芯的内阻表是 32 字节，按 big-endian `uint16` 解析成 16 个整数。这些值与 `ra00`–`ra14` 一起描述了电池在不同 SOC/温度点的内阻特征。跨机型、跨化学 ID 的具体映射由电量计算法决定，macli 只提供原始整数表，不发明物理含义。

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
| `estimatedFullChargeWh` | Wh | 按当前电压与 `maxCapacity` 估算的满电能量 |

### 电压 / 电流

| 字段 | 单位 | 说明 |
|---|---|---|
| `voltage` | mV | 电池包电压 |
| `amperage` | mA | 平均电流 |
| `instantAmperage` | mA | 瞬时电流 |
| `instantPowerWatts` | W | `voltage * instantAmperage / 1e6` |
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
| `manufacturerDataAscii` | string | `ManufacturerData` 中可打印的 ASCII 片段 |

### 电芯数据

| 字段 | 单位 | 说明 |
|---|---|---|
| `cellVoltages` | V | 每个电芯电压 |
| `cellVoltageDelta` | V | 最高电芯电压 - 最低电芯电压 |
| `qmax` | mAh | 每个电芯最大化学容量 |
| `cellWom` | - | cell wake-on-motion 标志 |
| `presentDOD` | - | 当前放电深度 |
| `dod0` | - | 初始 DOD 校准值 |
| `weightedRa` | mΩ | 加权内阻 |
| `cellCurrentAccumulator` | - | 电芯电流累积器 |
| `raTableRaw` | [uint16] | 每电芯内阻表（已从 `RaTableRaw` 解码） |
| `iMaxAndSocSmoothTable` | hex | 电流-电量平滑表（通常全 0） |

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
| `batteryStateBytes` | [uint8] | `BatteryState` 的 uint8 数组 |
| `mfgData` | hex | 制造商数据 |
| `mfgDataAscii` | string | `MfgData` 中可打印的 ASCII 片段 |

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
| `charger.powerWatts` | W | `charger.voltage * charger.current / 1e6` |
| `charger.status` | hex | 充电器状态字节 |
| `charger.statusBytes` | [uint8] | `ChargerStatus` 的 uint8 数组 |
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
| `raTableRaw` | `BatteryData.RaTableRaw` | 每电芯内阻表原始字节解码为 uint16 数组 |
| `iMaxAndSocSmoothTable` | `BatteryData.iMaxAndSocSmoothTable` | 电流-电量平滑表（hex） |
| `batteryStateBytes` | `BatteryData.BatteryState` | gas gauge 状态字节数组 |
| `mfgDataAscii` | `BatteryData.MfgData` | 制造商数据中的可打印 ASCII |
| `manufacturerDataAscii` | `AppleSmartBattery.ManufacturerData` | 顶层制造商数据 ASCII |
| `cellVoltageDelta` | `BatteryData.CellVoltage` | 电芯最大最小电压差 |
| `estimatedFullChargeWh` | `Voltage` × `AppleRawMaxCapacity` | 估算满电能量 |
| `instantPowerWatts` | `Voltage` × `InstantAmperage` | 瞬时功率 |
| `charger.powerWatts` | `ChargerData.ChargingVoltage` × `ChargingCurrent` | 当前充电功率 |
| `charger.statusBytes` | `ChargerData.ChargerStatus` | 充电器状态字节数组 |
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
- `LifetimeData.Raw`、`LifetimeData.TimeAtHighSoc` 等二进制时间序列（Apple 电量计私有格式）
- `PortControllerInfo` 里的 `PortControllerEvtBuffer` 等大块原始 buffer（USB-PD 控制器私有格式）

其余二进制字段（`BatteryState`、`ChargerStatus`、`MfgData`、`ManufacturerData`、`RaTableRaw`、`iMaxAndSocSmoothTable`）已以 hex 或结构化形式输出。

---

## 控制充电：macli battery 只读，控制请用这些工具

`macli battery` 是**观测/诊断工具**，它只读取 `IOKit` 数据，不修改电池或充电行为。如果你需要限制充电、暂停充电或做自动校准，请使用以下方案。

### 1. 官方原生方式（最稳）

macOS 官方提供**图形界面**的充电控制：

- **System Settings → Battery → Battery Health → Optimized Battery Charging**  
  让系统根据你的作息，在夜间暂缓充到 100%。
- **80% Limit**（部分 Apple Silicon 机型、较新 macOS）  
  直接把充电上限锁在 80%，适合长期插电使用。
- **Charging Limit（80%–100% 可调）**（macOS 26.4 及更高版本，据 [charlie0129/batt](https://github.com/charlie0129/batt) 项目公告）  
  系统原生支持将充电上限在 80% 到 100% 之间调节，无需第三方工具。  
  设置路径：**System Settings → Battery → 充电 → 充电上限**。

优点：Apple 官方支持，无需额外软件，系统升级不会失效。  
缺点：依然没有 CLI；如果需要低于 80% 的限制，仍需第三方工具。

### 2. `pmset` — 原生命令，但只能看不能控

`pmset` 是 macOS 自带的电源管理工具，可以查看电池和电源状态：

```sh
pmset -g batt        # 当前电池状态
pmset -g ps         # 电源源状态
pmset -g rawlog     # 原始电池状态日志
pmset -g log        # 电源事件日志
```

但它**没有充电限制功能**。它管理的是睡眠、唤醒、显示器关闭、低电量模式等系统电源策略，不是电池充电阈值。

### 3. 第三方 CLI 控制工具（功能强，但非官方）

| 工具 | 适用平台 | 原理 | 特点 |
|---|---|---|---|
| `batt` | Apple Silicon | 逆向 Apple 电源管理私有 API，通过守护进程控制充电 | 适合 macOS 26.4 之前，或需要低于 80% 的充电上限；功能丰富：上下限、定时校准、切电源、睡眠前停止充电 |
| `bclm` | Intel | 通过 SMC 设置 `BCLM` 键 | 轻量，但 Apple Silicon 不支持 |
| `AlDente` | Apple Silicon / Intel | 商业工具，使用 IOKit 私有 API | 有 GUI，功能多，部分功能付费 |

```sh
# batt（Apple Silicon）设置 80% 上限
brew install batt
sudo batt limit 80

# bclm（Intel）设置 80% 上限
brew tap zackelia/formulae
brew install bclm
sudo bclm write 80
```

> ⚠️ 这些工具都依赖未公开的接口或私有 API。macOS 大版本更新后可能需要等待工具更新，且不在 Apple 官方支持范围内。

### 4. 和 `macli battery` 的配合

推荐组合：

1. 日常充电策略用 **System Settings**（最稳）。
2. 用 `macli battery` 做遥测，验证策略是否生效：
   ```sh
   macli battery | jq '{stateOfCharge, isCharging, externalConnected, chargerPower: .charger.powerWatts}'
   ```
3. 如果系统版本低于 macOS 26.4，或需要把上限设到 80% 以下，再考虑 `batt` / `bclm`，并接受它们是私有/非官方方案。

---

## `macli battery` 与 `batt` / `bclm` 的关系

一句话：**不是替代关系，是互补关系。**

| 能力 | `macli battery` | `batt` | `bclm` |
|---|---|---|---|
| 核心目标 | **观测 / 诊断 / 遥测** | **控制充电**（Apple Silicon） | **控制充电**（Intel） |
| 能否设充电上限 | ❌ | ✅（macOS <26.4 或需 <80% 时用 `batt limit 80`） | ✅ `bclm write 80` |
| 能否暂停/恢复充电 | ❌ | ✅ `batt adapter disable/enable` | ❌ |
| 字段数量 | ~150+ | 仅状态所需（电量、是否充电、限制值等） | 无 |
| 电芯级数据 | ✅ `cellVoltages`、`cellVoltageDelta`、`qmax`、`raTableRaw` | ❌ | ❌ |
| 适配器/PD 诊断 | ✅ `adapter.usbHvcMenu`、`fedDetails`、`portControllerInfo` | ❌ | ❌ |
| 生命周期数据 | ✅ `lifetimeData.*` | ❌ | ❌ |
| 二进制 blob 解码 | ✅ `raTableRaw`、`batteryStateBytes`、`mfgDataAscii` | ❌ | ❌ |
| 是否需要守护进程 | 否 | 是 | 否 |
| 平台 | Apple Silicon / Intel | Apple Silicon | Intel |

### 为什么 `batt` 不能替代 `macli battery`？

`batt` 的定位非常聚焦：**把充电上限这件事做透**。它的 `batt status` 只会输出控制充电所需的最小信息（当前电量、是否在充电、限制值等），不会给你：

- 每个电芯的电压和内阻；
- USB-C PD 适配器的 PDO 档位和接了什么设备；
- 电池/充电器的原始状态字节；
- 生命周期温度、最大放电电流等诊断数据。

反过来说，`macli battery` 永远也不会去控制充电——这是两个不同的问题域。

### 推荐搭配

```sh
# 1. 用 macli battery 做全面体检
macli battery | jq '{healthPercent, cycleCount, cellVoltageDelta, temperature}'

# 2. 如果需要，再用 batt 设置充电上限（Apple Silicon）
sudo batt limit 80

# 3. 用 macli battery 验证 batt 是否生效
macli battery | jq '{stateOfCharge, isCharging, externalConnected, chargerPower: .charger.powerWatts}'
```

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
