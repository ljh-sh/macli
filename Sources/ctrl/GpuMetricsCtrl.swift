import Foundation
import IOKit

class GpuMetricsCtrl {
    func getMetrics() -> [String: Any] {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AGXAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return ["ok": false, "error": "Unable to enumerate AGXAccelerator services"]
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            var propsRef: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                  let props = propsRef?.takeRetainedValue() as? [String: Any] else {
                service = IOIteratorNext(iterator)
                continue
            }

            var result: [String: Any] = [
                "ok": true,
                "source": "AGXAccelerator",
            ]

            if let coreCount = props["gpu-core-count"] as? NSNumber {
                result["coreCount"] = coreCount.intValue
            }
            if let pluginName = props["MetalPluginName"] as? String {
                result["metalPluginName"] = pluginName
            }

            if let stats = props["PerformanceStatistics"] as? [String: Any] {
                result["performanceStatistics"] = stats
            }

            if result["performanceStatistics"] != nil || result["coreCount"] != nil {
                return result
            }

            service = IOIteratorNext(iterator)
        }

        return ["ok": false, "error": "No AGXAccelerator service found"]
    }

    func getNumericMetrics() -> [(name: String, value: Double, unit: String)] {
        let data = getMetrics()
        guard (data["ok"] as? Bool) == true,
              let stats = data["performanceStatistics"] as? [String: Any] else {
            return []
        }

        var result: [(name: String, value: Double, unit: String)] = []

        let mapping: [(key: String, name: String, unit: String)] = [
            ("Device Utilization %", "device_utilization", "%"),
            ("Renderer Utilization %", "renderer_utilization", "%"),
            ("Tiler Utilization %", "tiler_utilization", "%"),
            ("In use system memory", "in_use_system_memory", "B"),
            ("Alloc system memory", "alloc_system_memory", "B"),
            ("Allocation system memory", "allocation_system_memory", "B"),
        ]

        for entry in mapping {
            if let num = stats[entry.key] as? NSNumber {
                result.append((entry.name, num.doubleValue, entry.unit))
            }
        }

        return result
    }
}
