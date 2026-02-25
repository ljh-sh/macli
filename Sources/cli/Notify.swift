import Foundation

enum NotifyCmd: Cmd {
    static let meta = CmdMeta(
        name: "notify",
        alias: ["n"],
        desc: "Send system notifications",
        subcmds: [
            "send": NotifySend.self,
            "schedule": NotifySchedule.self,
        ]
    )
}

enum NotifySend: Cmd {
    static let meta = CmdMeta(
        name: "send",
        desc: "Send notification immediately",
        opts: [
            OptMeta(name: "--title", desc: "Title", `default`: "macli"),
            OptMeta(name: "--sound", type: Bool.self, desc: "Play sound"),
        ],
        args: [ArgMeta(name: "body", desc: "Notification body")],
        run: { p in
            let body: String = requireArg(p, 0, "Body")
            let title: String = p.opt("--title") ?? "macli"
            let sound: Bool = p.opt("--sound") ?? true
            let r = NotifyCtrl().send(title: title, body: body, sound: sound)
            print(x.json.stringify(r) { ["notification": $0.toDict()] })
        }
    )
}

enum NotifySchedule: Cmd {
    static let meta = CmdMeta(
        name: "schedule",
        desc: "Schedule notification",
        opts: [
            OptMeta(name: "--title", desc: "Title", `default`: "macli"),
            OptMeta(name: "--at", desc: "ISO8601 time", required: true),
        ],
        args: [ArgMeta(name: "body")],
        run: { p in
            let body: String = requireArg(p, 0, "Body")
            let title: String = p.opt("--title") ?? "macli"
            let at: String = requireOpt(p, "--at")
            guard let date = ISO8601DateFormatter().date(from: at) else { cmdError("Invalid --at format") }
            let r = NotifyCtrl().schedule(title: title, body: body, at: date)
            print(x.json.stringify(r) { ["notification": $0.toDict()] })
        }
    )
}
