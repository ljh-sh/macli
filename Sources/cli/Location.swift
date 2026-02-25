import Foundation

enum LocationCmd: Cmd {
    static let meta = CmdMeta(
        name: "location",
        desc: "Get current location",
        run: { _ in
            let acc = AccessCtrl(); try acc.askLocation()
            let r = MapCtrl().getCurLoc()
            print(x.json.stringify(r) { $0 })
        }
    )
}
