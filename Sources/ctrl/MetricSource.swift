import Foundation

// MetricSource: 抽象的指标源。monitor 子命令组合所有 source 做流式输出。
// 每个 source 负责一种数据（HID 温度、电压、电流等；未来可加 pmgr 频率等）。
// 与 smc 子命令的关系：smc 是 SMC 专门快照工具；monitor 共享底层取数代码
// 但不通过 spawn macli smc 子进程拿数据（直接函数调用）。

protocol MetricSource {
    var prefix: String { get }              // 列名前缀，如 "smc_temp"
    func sample() -> [(name: String, value: Double, unit: String)]
}

class SmcTempSource: MetricSource {
    let prefix = "smc_temp"
    private let hid = HidSensorCtrl()
    func sample() -> [(name: String, value: Double, unit: String)] {
        return hid.getTemperatures().map { ($0.name, $0.value, $0.unit) }
    }
}

class SmcVoltSource: MetricSource {
    let prefix = "smc_volt"
    private let hid = HidSensorCtrl()
    func sample() -> [(name: String, value: Double, unit: String)] {
        return hid.getVoltages().map { ($0.name, $0.value, $0.unit) }
    }
}

class SmcCurrSource: MetricSource {
    let prefix = "smc_curr"
    private let hid = HidSensorCtrl()
    func sample() -> [(name: String, value: Double, unit: String)] {
        return hid.getCurrents().map { ($0.name, $0.value, $0.unit) }
    }
}

// Sensor name sanitizer for column header (PMU tdie1 -> PMU_tdie1)
func sanitizeMetricName(_ s: String) -> String {
    return s.replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "-", with: "_")
}
