import Foundation

enum SsdCmd: Cmd {
    static let meta = CmdMeta(
        name: "ssd",
        desc: "SSD / NVMe drive info and SMART status",
        run: { _ in
            let data = SsdCtrl().getSsdInfo()
            print(x.json.stringify(data))
        }
    )
}
