import Foundation

enum ReminderCmd: Cmd {
    static let meta = CmdMeta(
        name: "reminder",
        alias: ["r"],
        desc: "Manage reminders",
        subcmds: [
            "ls": ReminderLs.self,
            "show": ReminderShow.self,
            "add": ReminderAdd.self,
            "rm": ReminderRm.self,
            "complete": ReminderComplete.self,
            "undo": ReminderUndo.self,
        ]
    )
    
    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "List reminders in a list", cmd: "macli reminder ls --list work"),
            TldrItem(desc: "Add a reminder", cmd: "macli reminder add --list work --title 'Buy milk' --due 2024-01-15"),
            TldrItem(desc: "Mark reminder as complete", cmd: "macli reminder complete <id>"),
            TldrItem(desc: "Undo completion", cmd: "macli reminder undo <id>"),
        ]
    }
}

enum ReminderLs: Cmd {
    static let meta = CmdMeta(
        name: "ls",
        desc: "List reminders",
        opts: [
            OptMeta(name: "--list", desc: "List ID", required: true),
            OptMeta(name: "--completed", desc: "Filter: true/false"),
        ],
        run: { p in
            let list: String = requireOpt(p, "--list")
            let completed: Bool? = p.opt("--completed") == "true" ? true : p.opt("--completed") == "false" ? false : nil
            let acc = AccessCtrl(); try acc.askReminder()
            let r = ReminderCtrl().listItems(listUid: CfgCtrl.getId(list), done: completed)
            print(x.json.stringify(r) { ["reminders": $0.map { $0.toDict() }, "count": $0.count] })
        }
    )
}

enum ReminderShow: Cmd {
    static let meta = CmdMeta(
        name: "show",
        desc: "Show reminder",
        args: [ArgMeta(name: "id")],
        run: { p in
            let id = requireArg(p, 0, "ID")
            let acc = AccessCtrl(); try acc.askReminder()
            let r = ReminderCtrl().getItem(uid: id)
            print(x.json.stringify(r) { ["reminder": $0.toDict()] })
        }
    )
}

enum ReminderAdd: Cmd {
    static let meta = CmdMeta(
        name: "add",
        desc: "Create reminder",
        opts: [
            OptMeta(name: "--list", desc: "List ID", required: true),
            OptMeta(name: "--title", desc: "Title", required: true),
            OptMeta(name: "--due", desc: "Due date"),
            OptMeta(name: "--priority", type: Int.self, desc: "Priority"),
            OptMeta(name: "--notes", desc: "Notes"),
        ],
        run: { p in
            let list: String = requireOpt(p, "--list")
            let title: String = requireOpt(p, "--title")
            let due = p.opt("--due").flatMap { DateParser.parse($0) }
            let priority: Int? = p.opt("--priority")
            let notes: String? = p.opt("--notes")
            let acc = AccessCtrl(); try acc.askReminder()
            let r = ReminderCtrl().addItem(listUid: CfgCtrl.getId(list), title: title, due: due, prio: priority ?? 0, note: notes)
            print(x.json.stringify(r) { ["reminder": $0.toDict()] })
        }
    )
}

enum ReminderRm: Cmd {
    static let meta = CmdMeta(name: "rm", args: [ArgMeta(name: "id")], run: { p in
        let id = requireArg(p, 0, "ID")
        let acc = AccessCtrl(); try acc.askReminder()
        let r = ReminderCtrl().delItem(uid: id)
        print(x.json.stringify(r) { ["deletedReminderId": $0] })
    })
}

enum ReminderComplete: Cmd {
    static let meta = CmdMeta(name: "complete", args: [ArgMeta(name: "id")], run: { p in
        let id = requireArg(p, 0, "ID")
        let acc = AccessCtrl(); try acc.askReminder()
        let r = ReminderCtrl().markDone(uid: id)
        print(x.json.stringify(r) { ["reminder": $0.toDict()] })
    })
}

enum ReminderUndo: Cmd {
    static let meta = CmdMeta(name: "undo", args: [ArgMeta(name: "id")], run: { p in
        let id = requireArg(p, 0, "ID")
        let acc = AccessCtrl(); try acc.askReminder()
        let r = ReminderCtrl().undo(uid: id)
        print(x.json.stringify(r) { ["reminder": $0.toDict()] })
    })
}
