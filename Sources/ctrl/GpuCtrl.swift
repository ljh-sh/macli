import Foundation
import Metal
import IOKit

class GpuCtrl {
    func getGpuInfo() -> [String: Any] {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return ["ok": false, "error": "Metal is not available on this system"]
        }

        var result: [String: Any] = [
            "ok": true,
            "source": "Metal/IOKit",
            "name": device.name,
            "hasUnifiedMemory": device.hasUnifiedMemory,
        ]

        if #available(macOS 10.13, *) {
            result["recommendedMaxWorkingSetSizeBytes"] = device.recommendedMaxWorkingSetSize
        }

        if let coreCount = readGpuCoreCount() {
            result["coreCount"] = coreCount
        }

        return result
    }

    private func readGpuCoreCount() -> Int? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AGXAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let number = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                return number.intValue
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }
}
