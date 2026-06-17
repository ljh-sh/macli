import Foundation
import HidSensorObjC

class PowerCtrl {
    func getPower() -> [String: Any] {
        return PowerClient.getPowerInfo()
    }
}
