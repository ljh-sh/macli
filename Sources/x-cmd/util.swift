import Foundation

// MARK: JSON Output

extension R {
    func toDict(convert: (T) -> [String: Any]) -> [String: Any] {
        switch self {
        case .ok(let v):
            var d = convert(v)
            if d["ok"] == nil { d["ok"] = true }
            return d
        case .err(let m):
            return ["ok": false, "error": m]
        }
    }
}

enum XCMD {
    enum json {
        static func stringify<T>(_ r: R<T>, convert: (T) -> [String: Any]) -> String {
            return stringify(r.toDict(convert: convert))
        }
        
        static func stringify(_ data: [String: Any]) -> String {
            do {
                let d = try JSONSerialization.data(
                    withJSONObject: data,
                    options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
                )
                return String(data: d, encoding: .utf8) ?? "{\"error\": \"encode failed\"}"
            } catch {
                return "{\"ok\": false, \"error\": \"JSON failed: \(error.localizedDescription)\"}"
            }
        }
    }
    
    enum yaml {
        static func stringify<T>(_ r: R<T>, convert: (T) -> [String: Any]) -> String {
            return SimpleYaml.dump(r.toDict(convert: convert))
        }
        
        static func stringify(_ data: [String: Any]) -> String {
            return SimpleYaml.dump(data)
        }
    }
}

// MARK: Model to Dict

extension CalInfo {
    func toDict() -> [String: Any] {
        [
            "id": uid,
            "title": name,
            "type": kind,
            "source": src,
            "color": color,
            "allowsModifications": canEdit,
            "calendarType": calType,
            "subscribed": isSubscribed,
            "immutable": isImmutable
        ]
    }
}

extension CalRef {
    func toDict() -> [String: Any] {
        ["id": uid, "title": name]
    }
}

extension EventInfo {
    func toDict() -> [String: Any] {
        var d: [String: Any] = [
            "id": uid,
            "title": title,
            "calendar": cal.toDict(),
            "allDay": isAllDay,
            "hasAlarms": hasAlarm,
            "hasRecurrenceRules": hasRepeat
        ]
        if let s = start { d["startDate"] = fmtDate(s) }
        if let e = end { d["endDate"] = fmtDate(e) }
        d["location"] = loc ?? NSNull()
        d["notes"] = note ?? NSNull()
        if let l = link { d["url"] = l }
        return d
    }
}

extension ReminderList {
    func toDict() -> [String: Any] {
        [
            "id": uid,
            "title": name,
            "source": src,
            "color": color,
            "allowsModifications": canEdit
        ]
    }
}

extension ReminderInfo {
    func toDict() -> [String: Any] {
        var d: [String: Any] = [
            "id": uid,
            "title": title,
            "list": list.toDict(),
            "completed": isDone,
            "priority": prio
        ]
        if let da = doneAt { d["completionDate"] = fmtDate(da) }
        if let du = due { d["dueDate"] = fmtDate(du) }
        d["notes"] = note ?? NSNull()
        if let l = link { d["url"] = l }
        return d
    }
}

extension PlaceInfo {
    func toDict() -> [String: Any] {
        var d: [String: Any] = [
            "name": name,
            "latitude": lat,
            "longitude": lng
        ]
        d["address"] = addr ?? NSNull()
        return d
    }
}

extension RouteStep {
    func toDict() -> [String: Any] {
        ["instruction": instr, "distance": dist]
    }
}

extension RouteInfo {
    func toDict() -> [String: Any] {
        [
            "distance": dist,
            "duration": dur,
            "steps": steps.map { $0.toDict() }
        ]
    }
}


