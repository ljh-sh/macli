import Foundation

enum EventCmd: Cmd {
    static let meta = CmdMeta(
        name: "event",
        alias: ["e"],
        desc: "Manage calendar events",
        subcmds: [
            "ls": EventLs.self,
            "show": EventShow.self,
            "add": EventAdd.self,
            "edit": EventEdit.self,
            "rm": EventRm.self,
        ]
    )
    
    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "List today's events", cmd: "macli event ls --calendar work --today"),
            TldrItem(desc: "List this week's events", cmd: "macli event ls --calendar work --week"),
            TldrItem(desc: "Add an event", cmd: "macli event add --calendar work --title Meeting --start 2024-01-15T10:00 --end 2024-01-15T11:00"),
            TldrItem(desc: "Delete an event", cmd: "macli event rm <id>"),
        ]
    }
}

enum EventLs: Cmd {
    static let meta = CmdMeta(
        name: "ls",
        desc: "List events in a date range",
        opts: [
            OptMeta(name: "--calendar", desc: "Calendar ID or aka", required: true),
            OptMeta(name: "--from", desc: "Start date (ISO8601 or today/tomorrow/+7)"),
            OptMeta(name: "--to", desc: "End date"),
            OptMeta(name: "--today", type: Bool.self, desc: "Today's events"),
            OptMeta(name: "--week", type: Bool.self, desc: "This week's events"),
            OptMeta(name: "--month", type: Bool.self, desc: "This month's events"),
        ],
        run: { p in
            let calendar: String = requireOpt(p, "--calendar")
            let today: Bool = p.opt("--today") ?? false
            let week: Bool = p.opt("--week") ?? false
            let month: Bool = p.opt("--month") ?? false
            let from: String? = p.opt("--from")
            let to: String? = p.opt("--to")
            
            var start: Date?, end: Date?
            if today {
                start = DateParser.startOfDay(Date()); end = DateParser.endOfDay(Date())
            } else if week {
                let c = Calendar.current
                start = c.date(from: c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))
                end = c.date(byAdding: .day, value: 7, to: start!)
            } else if month {
                let c = Calendar.current
                start = c.date(from: c.dateComponents([.year, .month], from: Date()))
                end = c.date(byAdding: .month, value: 1, to: start!)
            } else {
                guard let fromVal = from, let s = DateParser.parse(fromVal) else { cmdError("--from required") }
                guard let toVal = to, let e = DateParser.parse(toVal) else { cmdError("--to required") }
                start = s
                end = DateParser.endOfDay(e)
            }
            
            let acc = AccessCtrl(); try acc.askCal()
            let r = CalendarEventCtrl().list(calUid: CfgCtrl.getId(calendar), from: start!, to: end!)
            print(x.json.stringify(r) { ["events": $0.map { $0.toDict() }, "count": $0.count] })
        }
    )
}

enum EventShow: Cmd {
    static let meta = CmdMeta(
        name: "show",
        desc: "Show event by ID",
        args: [ArgMeta(name: "id", desc: "Event ID")],
        run: { p in
            let id = requireArg(p, 0, "Event ID")
            let acc = AccessCtrl(); try acc.askCal()
            let r = CalendarEventCtrl().get(uid: id)
            print(x.json.stringify(r) { ["event": $0.toDict()] })
        }
    )
}

enum EventAdd: Cmd {
    static let meta = CmdMeta(
        name: "add",
        desc: "Create event",
        opts: [
            OptMeta(name: "--calendar", desc: "Calendar ID", required: true),
            OptMeta(name: "--title", desc: "Event title", required: true),
            OptMeta(name: "--start", desc: "Start date", required: true),
            OptMeta(name: "--end", desc: "End date", required: true),
            OptMeta(name: "--location", desc: "Location"),
            OptMeta(name: "--notes", desc: "Notes"),
            OptMeta(name: "--all-day", type: Bool.self, desc: "All-day event"),
            OptMeta(name: "--alarm", type: Int.self, desc: "Alarm minutes before"),
        ],
        run: { p in
            let calendar: String = requireOpt(p, "--calendar")
            let title: String = requireOpt(p, "--title")
            let startStr: String = requireOpt(p, "--start")
            let endStr: String = requireOpt(p, "--end")
            guard let start = DateParser.parse(startStr) else { cmdError("--start invalid") }
            guard let end = DateParser.parse(endStr) else { cmdError("--end invalid") }
            let location: String? = p.opt("--location")
            let notes: String? = p.opt("--notes")
            let allDay: Bool = p.opt("--all-day") ?? false
            let alarm: Int? = p.opt("--alarm")
            
            let acc = AccessCtrl(); try acc.askCal()
            let r = CalendarEventCtrl().add(calUid: CfgCtrl.getId(calendar), title: title, start: start, end: end, loc: location, note: notes, allDay: allDay, alarmMins: alarm)
            print(x.json.stringify(r) { ["event": $0.toDict()] })
        }
    )
}

enum EventEdit: Cmd {
    static let meta = CmdMeta(
        name: "edit",
        desc: "Update event",
        opts: [
            OptMeta(name: "--title", desc: "New title"),
            OptMeta(name: "--start", desc: "New start"),
            OptMeta(name: "--end", desc: "New end"),
            OptMeta(name: "--location", desc: "New location"),
            OptMeta(name: "--notes", desc: "New notes"),
            OptMeta(name: "--all-day", type: Bool.self, desc: "All-day"),
        ],
        args: [ArgMeta(name: "id", desc: "Event ID")],
        run: { p in
            let id = requireArg(p, 0, "Event ID")
            let title: String? = p.opt("--title")
            let start = p.opt("--start").flatMap { DateParser.parse($0) }
            let end = p.opt("--end").flatMap { DateParser.parse($0) }
            let location: String? = p.opt("--location")
            let notes: String? = p.opt("--notes")
            var allDay: Bool?; if p.opt("--all-day") ?? false { allDay = true }
            
            let acc = AccessCtrl(); try acc.askCal()
            let r = CalendarEventCtrl().mod(uid: id, title: title, start: start, end: end, loc: location, note: notes, allDay: allDay)
            print(x.json.stringify(r) { ["event": $0.toDict()] })
        }
    )
}

enum EventRm: Cmd {
    static let meta = CmdMeta(
        name: "rm",
        desc: "Delete event",
        args: [ArgMeta(name: "id", desc: "Event ID")],
        run: { p in
            let id = requireArg(p, 0, "Event ID")
            let acc = AccessCtrl(); try acc.askCal()
            let r = CalendarEventCtrl().del(uid: id)
            print(x.json.stringify(r) { ["deletedEventId": $0] })
        }
    )
}
