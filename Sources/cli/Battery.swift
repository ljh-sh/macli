import Foundation

enum BatteryCmd: Cmd {
    static let meta = CmdMeta(
        name: "battery",
        desc: "Battery health and status via IOKit",
        run: { _ in
            var data = BatteryCtrl().getBattery()
            data["ok"] = true
            print(x.json.stringify(data))
        }
    )
}
