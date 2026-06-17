import Foundation
import HidSensorObjC

class BatteryCtrl {
    func getBattery() -> [String: Any] {
        return BatteryClient.getBatteryInfo()
    }
}
