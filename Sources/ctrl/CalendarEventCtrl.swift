import EventKit
import Foundation

class CalendarEventCtrl {
    private let ek = Store.ek

    // MARK: Event Ops
    func list(calUid: String, from: Date, to: Date) -> R<[EventInfo]> {
        let log = Log.with("Event")
        log.d("Listing events", more: ["calUid": calUid])
        
        guard let cal = ek.calendar(withIdentifier: calUid) else {
            log.e("Calendar not found")
            return .err("Calendar not found: \(calUid)")
        }
        
        let pred = ek.predicateForEvents(withStart: from, end: to, calendars: [cal])
        let evts = ek.events(matching: pred).map { fmt($0) }
        
        log.i("Listed events", more: ["count": evts.count])
        return .ok(evts)
    }

    func get(uid: String) -> R<EventInfo> {
        let log = Log.with("Event")
        log.d("Getting event", more: ["uid": uid])
        
        guard let e = ek.event(withIdentifier: uid) else {
            log.e("Not found")
            return .err("Event not found: \(uid)")
        }
        return .ok(fmt(e))
    }

    func add(
        calUid: String,
        title: String,
        start: Date,
        end: Date,
        loc: String?,
        note: String?,
        allDay: Bool,
        alarmMins: Int? = nil
    ) -> R<EventInfo> {
        let log = Log.with("Event")
        log.d("Adding event", more: ["title": title, "calUid": calUid])
        
        guard let cal = ek.calendar(withIdentifier: calUid) else {
            log.e("Calendar not found")
            return .err("Calendar not found: \(calUid)")
        }
        
        guard cal.allowsContentModifications else {
            log.e("No edit permission")
            return .err("Calendar '\(cal.title)' is read-only")
        }
        
        let e = EKEvent(eventStore: ek)
        e.calendar = cal
        e.title = title
        e.startDate = start
        e.endDate = end
        e.location = loc
        e.notes = note
        e.isAllDay = allDay
        
        if let mins = alarmMins {
            e.addAlarm(EKAlarm(relativeOffset: -Double(mins * 60)))
        }
        
        do {
            try ek.save(e, span: .thisEvent)
            log.i("Event created", more: ["title": title])
            return .ok(fmt(e))
        } catch {
            log.e("Failed to create", more: ["err": error.localizedDescription])
            return .err("Failed to create: \(error.localizedDescription)")
        }
    }

    func del(uid: String) -> R<String> {
        let log = Log.with("Event")
        log.d("Deleting event", more: ["uid": uid])
        
        guard let e = ek.event(withIdentifier: uid) else {
            log.e("Not found")
            return .err("Event not found: \(uid)")
        }
        
        let t = e.title ?? "Untitled"
        do {
            try ek.remove(e, span: .thisEvent)
            log.i("Deleted", more: ["title": t])
            return .ok(uid)
        } catch {
            log.e("Failed to delete", more: ["err": error.localizedDescription])
            return .err("Failed to delete: \(error.localizedDescription)")
        }
    }

    func mod(
        uid: String,
        title: String?,
        start: Date?,
        end: Date?,
        loc: String?,
        note: String?,
        allDay: Bool?
    ) -> R<EventInfo> {
        let log = Log.with("Event")
        log.d("Updating event", more: ["uid": uid])
        
        guard let e = ek.event(withIdentifier: uid) else {
            log.e("Not found")
            return .err("Event not found: \(uid)")
        }
        
        if let t = title { e.title = t }
        if let s = start { e.startDate = s }
        if let en = end { e.endDate = en }
        if let l = loc { e.location = l }
        if let n = note { e.notes = n }
        if let a = allDay { e.isAllDay = a }
        
        do {
            try ek.save(e, span: .thisEvent)
            log.i("Updated")
            return .ok(fmt(e))
        } catch {
            log.e("Failed to update", more: ["err": error.localizedDescription])
            return .err("Failed to update: \(error.localizedDescription)")
        }
    }

    // MARK: Helpers
    private func fmt(_ e: EKEvent) -> EventInfo {
        EventInfo(
            uid: e.eventIdentifier ?? "",
            title: e.title ?? "",
            cal: CalRef(
                uid: e.calendar?.calendarIdentifier ?? "",
                name: e.calendar?.title ?? ""
            ),
            isAllDay: e.isAllDay,
            start: e.startDate,
            end: e.endDate,
            loc: e.location?.isEmpty == false ? e.location : nil,
            note: e.notes?.isEmpty == false ? e.notes : nil,
            link: e.url?.absoluteString,
            hasAlarm: e.hasAlarms,
            hasRepeat: e.hasRecurrenceRules
        )
    }
}
