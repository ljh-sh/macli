import EventKit
import Foundation

class CalendarCtrl {
    private let ek = Store.ek

    // MARK: Calendar Ops
    func list() -> R<[CalInfo]> {
        let log = Log.with("Cal")
        log.d("Listing calendars")
        
        let cals = ek.calendars(for: .event).map { fmtCal($0, kind: "event") }
        log.i("Listed calendars")
        return .ok(cals)
    }

    func listAll() -> R<[CalInfo]> {
        let log = Log.with("Cal")
        log.d("Listing all calendars and reminder lists")
        
        var all: [CalInfo] = []
        for c in ek.calendars(for: .event) {
            all.append(fmtCal(c, kind: "event"))
        }
        for c in ek.calendars(for: .reminder) {
            all.append(fmtCal(c, kind: "reminder"))
        }
        log.i("Listed all")
        return .ok(all)
    }

    func create(name: String, kind: String, color: String?) -> R<CalInfo> {
        let log = Log.with("Cal")
        log.d("Creating calendar", more: ["name": name, "kind": kind])
        
        let t: EKEntityType = (kind == "reminder") ? .reminder : .event
        let c = EKCalendar(for: t, eventStore: ek)
        c.title = name
        
        if let h = color, let cg = Colr.toCG(h) { c.cgColor = cg }
        
        guard let src = ek.sources.first else {
            log.e("No source available")
            return .err("No calendar source available")
        }
        c.source = src
        
        do {
            try ek.saveCalendar(c, commit: true)
            log.i("Calendar created", more: ["name": name])
            return .ok(fmtCal(c, kind: kind))
        } catch {
            log.e("Failed to create", more: ["err": error.localizedDescription])
            return .err("Failed to create: \(error.localizedDescription)")
        }
    }

    func del(uid: String) -> R<String> {
        let log = Log.with("Cal")
        log.d("Deleting calendar", more: ["uid": uid])
        
        guard let c = ek.calendar(withIdentifier: uid) else {
            log.e("Not found")
            return .err("Calendar not found: \(uid)")
        }
        
        let n = c.title
        do {
            try ek.removeCalendar(c, commit: true)
            log.i("Deleted", more: ["name": n])
            return .ok(uid)
        } catch {
            log.e("Failed to delete", more: ["err": error.localizedDescription])
            return .err("Failed to delete: \(error.localizedDescription)")
        }
    }

    // MARK: Helpers
    private func fmtCal(_ c: EKCalendar, kind: String) -> CalInfo {
        CalInfo(
            uid: c.calendarIdentifier,
            name: c.title,
            kind: kind,
            src: c.source?.title ?? "Unknown",
            color: c.cgColor.map { Colr.toHexStrFromCG($0) } ?? "#000000",
            canEdit: c.allowsContentModifications,
            calType: calTypeStr(c.type),
            isSubscribed: c.isSubscribed,
            isImmutable: c.isImmutable
        )
    }
    
    private func calTypeStr(_ t: EKCalendarType) -> String {
        switch t {
        case .local: return "local"
        case .calDAV: return "caldav"
        case .exchange: return "exchange"
        case .subscription: return "subscription"
        case .birthday: return "birthday"
        @unknown default: return "unknown"
        }
    }
}
