import Foundation
import CoreGraphics
import Darwin

class DisplayCtrl {
    private typealias CanChangeBrightnessFunc = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias BrightnessChangedFunc = @convention(c) (CGDirectDisplayID, Double) -> Void

    private static let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"

    private var handle: UnsafeMutableRawPointer?
    private var canChange: CanChangeBrightnessFunc?
    private var getBrightness: GetBrightnessFunc?
    private var setBrightness: SetBrightnessFunc?
    private var brightnessChanged: BrightnessChangedFunc?

    init() {
        handle = dlopen(DisplayCtrl.frameworkPath, RTLD_NOW)
        guard let handle = handle else {
            return
        }
        canChange = unsafeBitCast(dlsym(handle, "DisplayServicesCanChangeBrightness"), to: CanChangeBrightnessFunc.self)
        getBrightness = unsafeBitCast(dlsym(handle, "DisplayServicesGetBrightness"), to: GetBrightnessFunc.self)
        setBrightness = unsafeBitCast(dlsym(handle, "DisplayServicesSetBrightness"), to: SetBrightnessFunc.self)
        brightnessChanged = unsafeBitCast(dlsym(handle, "DisplayServicesBrightnessChanged"), to: BrightnessChangedFunc.self)
    }

    deinit {
        if let handle = handle {
            dlclose(handle)
        }
    }

    func getDisplays() -> [String: Any] {
        var displays: [[String: Any]] = []
        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        guard CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount) == .success else {
            return ["ok": false, "error": "Unable to enumerate displays"]
        }

        for i in 0..<Int(displayCount) {
            let id = onlineDisplays[i]
            var entry: [String: Any] = [
                "id": id,
                "main": CGDisplayIsMain(id),
                "builtIn": CGDisplayIsBuiltin(id),
                "active": CGDisplayIsActive(id),
            ]
            if let brightness = readBrightness(id: id) {
                entry["brightness"] = brightness
            }
            displays.append(entry)
        }

        return [
            "ok": true,
            "source": "DisplayServices",
            "displays": displays,
        ]
    }

    func setBrightness(_ value: Float, displayID: CGDirectDisplayID? = nil) -> [String: Any] {
        guard let setBrightness = setBrightness, let canChange = canChange else {
            return ["ok": false, "error": "DisplayServices framework is not available"]
        }

        var targetID = displayID
        if targetID == nil {
            targetID = findMainOrChangeableDisplay()
        }
        guard let id = targetID else {
            return ["ok": false, "error": "No adjustable display found"]
        }

        guard canChange(id) else {
            return ["ok": false, "error": "Display 0x\(String(id, radix: 16)) does not support brightness changes"]
        }

        let clamped = max(0.0, min(1.0, value))
        let result = setBrightness(id, clamped)
        guard result == 0 else {
            return ["ok": false, "error": "DisplayServicesSetBrightness returned \(result)"]
        }

        brightnessChanged?(id, Double(clamped))

        return [
            "ok": true,
            "displayID": id,
            "brightness": clamped,
        ]
    }

    private func findMainOrChangeableDisplay() -> CGDirectDisplayID? {
        let main = CGMainDisplayID()
        if canChange?(main) == true {
            return main
        }

        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount) == .success else {
            return nil
        }
        for i in 0..<Int(displayCount) {
            let id = onlineDisplays[i]
            if canChange?(id) == true {
                return id
            }
        }
        return nil
    }

    private func readBrightness(id: CGDirectDisplayID) -> Float? {
        guard let getBrightness = getBrightness, let canChange = canChange, canChange(id) else {
            return nil
        }
        var brightness: Float = 0
        guard getBrightness(id, &brightness) == 0 else {
            return nil
        }
        return brightness
    }

}
