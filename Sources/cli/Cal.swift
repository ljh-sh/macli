import Foundation

enum CalCmd: Cmd {
    static let meta = CmdMeta(
        name: "cal",
        alias: ["c"],
        desc: "Manage calendars",
        subcmds: [
            "ls": CalLs.self,
            "la": CalLa.self,
            "add": CalAdd.self,
            "rm": CalRm.self,
        ]
    )
    
    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "List all calendars", cmd: "macli cal ls"),
            TldrItem(desc: "List calendars and reminder lists", cmd: "macli cal la"),
            TldrItem(desc: "Create a new calendar", cmd: "macli cal add --name Work --color #FF0000"),
            TldrItem(desc: "Delete a calendar", cmd: "macli cal rm <id> --yes"),
            TldrItem(desc: "Delete a reminder list", cmd: "macli cal rm <id> --type reminder --yes"),
        ]
    }
}

enum CalLs: Cmd {
    static let meta = CmdMeta(
        name: "ls",
        desc: "List calendars (event calendars only)",
        run: { _ in
            let acc = AccessCtrl(); try acc.askCal()
            let r = CalendarCtrl().list()
            print(x.json.stringify(r) { ["calendars": $0.map { $0.toDict() }] })
        }
    )
}

enum CalLa: Cmd {
    static let meta = CmdMeta(
        name: "la",
        desc: "List all (calendars + reminder lists)",
        run: { _ in
            let acc = AccessCtrl(); try acc.askCal(); try acc.askReminder()
            let r = CalendarCtrl().listAll()
            print(x.json.stringify(r) { ["calendars": $0.map { $0.toDict() }] })
        }
    )
}

enum CalAdd: Cmd {
    static let meta = CmdMeta(
        name: "add",
        desc: "Create a new calendar",
        opts: [
            OptMeta(name: "--name", desc: "Calendar name", required: true),
            OptMeta(name: "--type", desc: "Type: event or reminder", `default`: "event"),
            OptMeta(name: "--color", desc: "Color in hex (e.g., #FF0000)"),
        ],
        run: { p in
            let name: String = requireOpt(p, "--name")
            let type: String = p.opt("--type") ?? "event"
            let color: String? = p.opt("--color")
            
            let acc = AccessCtrl()
            if type == "reminder" { try acc.askReminder() } else { try acc.askCal() }
            let r = CalendarCtrl().create(name: name, kind: type, color: color)
            print(x.json.stringify(r) { ["calendar": $0.toDict()] })
        }
    )
}

enum CalRm: Cmd {
    static let meta = CmdMeta(
        name: "rm",
        desc: "Delete a calendar",
        opts: [
            OptMeta(name: "--type", desc: "Type: event or reminder (default: event)", `default`: "event"),
            OptMeta(name: "--yes", type: Bool.self, desc: "Confirm destructive deletion"),
        ],
        args: [ArgMeta(name: "id", desc: "Calendar ID")],
        run: { p in
            let id = requireArg(p, 0, "Calendar ID")
            guard p.opt("--yes") == true else {
                cmdError("refusing to delete calendar without --yes")
            }
            let type: String = p.opt("--type") ?? "event"
            let acc = AccessCtrl()
            if type == "reminder" { try acc.askReminder() } else { try acc.askCal() }
            let r = CalendarCtrl().del(uid: CfgCtrl.getId(id))
            print(x.json.stringify(r) { ["deletedCalendarId": $0] })
        }
    )
}
