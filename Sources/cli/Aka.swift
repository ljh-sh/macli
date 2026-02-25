import Foundation

enum AkaCmd: Cmd {
    static let meta = CmdMeta(
        name: "aka",
        alias: ["a"],
        desc: "Manage calendar aliases",
        subcmds: [
            "ls": AkaLs.self,
            "set": AkaSet.self,
            "rm": AkaRm.self,
        ]
    )
    
    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "List all aliases", cmd: "macli aka ls"),
            TldrItem(desc: "Set an alias for calendar ID", cmd: "macli aka set work <calendar-id>"),
            TldrItem(desc: "Remove an alias", cmd: "macli aka rm work"),
        ]
    }
}

enum AkaLs: Cmd {
    static let meta = CmdMeta(
        name: "ls",
        desc: "List all aliases",
        run: { _ in
            let aka = CfgCtrl.getAka()
            let list = aka.sorted { $0.key < $1.key }.map { ["name": $0.key, "id": $0.value] }
            print(x.json.stringify(["aka": list, "count": list.count, "configPath": CfgCtrl.configPath()]))
        }
    )
}

enum AkaSet: Cmd {
    static let meta = CmdMeta(
        name: "set",
        desc: "Set an alias",
        args: [
            ArgMeta(name: "name", desc: "Alias name"),
            ArgMeta(name: "id", desc: "Calendar ID"),
        ],
        run: { p in
            guard let name = p.arg(0), let id = p.arg(1) else { cmdError("Usage: macli aka set <name> <id>") }
            try CfgCtrl.setAka(name: name, id: id)
            print(x.json.stringify(["ok": true, "message": "Aka '\(name)' set"]))
        }
    )
}

enum AkaRm: Cmd {
    static let meta = CmdMeta(
        name: "rm",
        desc: "Remove an alias",
        args: [ArgMeta(name: "name", desc: "Alias name")],
        run: { p in
            guard let name = p.arg(0) else { cmdError("Aka name required") }
            let removed = try CfgCtrl.rmAka(name: name)
            if removed { print(x.json.stringify(["ok": true, "message": "Aka '\(name)' removed"])) }
            else { cmdError("Aka '\(name)' not found") }
        }
    )
}
