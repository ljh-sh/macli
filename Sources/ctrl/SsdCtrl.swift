import Foundation

class SsdCtrl {
    /// Run a command and return its stdout as Data.
    private func shell(_ args: [String]) -> Data? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return task.terminationStatus == 0 ? data : nil
        } catch {
            return nil
        }
    }

    func getSsdInfo() -> [String: Any] {
        guard let data = shell(["system_profiler", "SPNVMeDataType", "-xml"]) else {
            return ["ok": false, "error": "Failed to run system_profiler SPNVMeDataType"]
        }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
            return ["ok": false, "error": "Failed to parse system_profiler output"]
        }

        guard let top = plist as? [[String: Any]] else {
            return ["ok": false, "error": "Unexpected system_profiler output structure"]
        }

        var controllers: [[String: Any]] = []
        for entry in top {
            guard let items = entry["_items"] as? [[String: Any]] else { continue }
            for controller in items {
                var controllerDict: [String: Any] = [:]
                controllerDict["name"] = controller["_name"] as? String ?? "Unknown"
                if let drives = controller["_items"] as? [[String: Any]] {
                    controllerDict["drives"] = drives.map { driveDict($0) }
                } else {
                    controllerDict["drives"] = [driveDict(controller)]
                }
                controllers.append(controllerDict)
            }
        }

        return [
            "ok": true,
            "source": "system_profiler",
            "controllers": controllers,
            "note": "SSD wear percentage is not exposed by macOS; use smartctl for detailed SMART data."
        ]
    }

    private func driveDict(_ drive: [String: Any]) -> [String: Any] {
        var volumes: [[String: Any]] = []
        if let vols = drive["volumes"] as? [[String: Any]] {
            volumes = vols.map {
                [
                    "name": $0["_name"] as? String ?? "",
                    "bsdName": $0["bsd_name"] as? String ?? "",
                    "size": $0["size"] as? String ?? "",
                    "sizeInBytes": $0["size_in_bytes"] as? Int ?? 0,
                    "content": $0["iocontent"] as? String ?? ""
                ]
            }
        }
        return [
            "name": drive["_name"] as? String ?? drive["device_model"] as? String ?? "Unknown",
            "model": drive["device_model"] as? String ?? "",
            "serial": drive["device_serial"] as? String ?? "",
            "revision": drive["device_revision"] as? String ?? "",
            "bsdName": drive["bsd_name"] as? String ?? "",
            "size": drive["size"] as? String ?? "",
            "sizeInBytes": drive["size_in_bytes"] as? Int ?? 0,
            "smartStatus": drive["smart_status"] as? String ?? "",
            "trimSupport": drive["spnvme_trim_support"] as? String ?? "",
            "removable": drive["removable_media"] as? String ?? "",
            "volumes": volumes
        ]
    }
}
