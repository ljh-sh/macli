import EventKit
import Foundation

class ReminderCtrl {
    private let ek = Store.ek

    // MARK: Reminder Ops
    func listItems(listUid: String, done: Bool?) -> R<[ReminderInfo]> {
        let log = Log.with("Reminder")
        log.d("Listing reminders", more: ["listUid": listUid])
        
        guard let cal = ek.calendar(withIdentifier: listUid) else {
            log.e("List not found")
            return .err("List not found: \(listUid)")
        }

        let pred = ek.predicateForReminders(in: [cal])
        var items: [EKReminder] = []
        let sem = DispatchSemaphore(value: 0)

        ek.fetchReminders(matching: pred) { fetched in
            if let f = fetched { items = f }
            sem.signal()
        }
        sem.wait()

        if let d = done { items = items.filter { $0.isCompleted == d } }

        let infos = items.map { fmtReminder($0) }
        log.i("Listed reminders", more: ["count": infos.count])
        return .ok(infos)
    }

    func getItem(uid: String) -> R<ReminderInfo> {
        let log = Log.with("Reminder")
        log.d("Getting reminder", more: ["uid": uid])
        
        guard let r = ek.calendarItem(withIdentifier: uid) as? EKReminder else {
            log.e("Not found")
            return .err("Reminder not found: \(uid)")
        }
        return .ok(fmtReminder(r))
    }

    func addItem(
        listUid: String,
        title: String,
        due: Date?,
        prio: Int,
        note: String?
    ) -> R<ReminderInfo> {
        let log = Log.with("Reminder")
        log.d("Adding reminder", more: ["title": title, "listUid": listUid])
        
        guard let cal = ek.calendar(withIdentifier: listUid) else {
            log.e("List not found")
            return .err("List not found: \(listUid)")
        }

        guard cal.allowsContentModifications else {
            log.e("No edit permission")
            return .err("List '\(cal.title)' is read-only")
        }

        let r = EKReminder(eventStore: ek)
        r.calendar = cal
        r.title = title
        r.priority = prio
        r.notes = note

        if let d = due {
            r.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: d
            )
        }

        do {
            try ek.save(r, commit: true)
            log.i("Reminder created", more: ["title": title])
            return .ok(fmtReminder(r))
        } catch {
            log.e("Failed to create", more: ["err": error.localizedDescription])
            return .err("Failed to create: \(error.localizedDescription)")
        }
    }

    func markDone(uid: String) -> R<ReminderInfo> {
        let log = Log.with("Reminder")
        log.d("Completing reminder", more: ["uid": uid])
        
        guard let r = ek.calendarItem(withIdentifier: uid) as? EKReminder else {
            log.e("Not found")
            return .err("Reminder not found: \(uid)")
        }

        r.isCompleted = true
        r.completionDate = Date()

        do {
            try ek.save(r, commit: true)
            log.i("Completed", more: ["title": r.title ?? ""])
            return .ok(fmtReminder(r))
        } catch {
            log.e("Failed to complete", more: ["err": error.localizedDescription])
            return .err("Failed to complete: \(error.localizedDescription)")
        }
    }

    func undo(uid: String) -> R<ReminderInfo> {
        let log = Log.with("Reminder")
        log.d("Undoing reminder", more: ["uid": uid])
        
        guard let r = ek.calendarItem(withIdentifier: uid) as? EKReminder else {
            log.e("Not found")
            return .err("Reminder not found: \(uid)")
        }

        r.isCompleted = false
        r.completionDate = nil

        do {
            try ek.save(r, commit: true)
            log.i("Reopened", more: ["title": r.title ?? ""])
            return .ok(fmtReminder(r))
        } catch {
            log.e("Failed to reopen", more: ["err": error.localizedDescription])
            return .err("Failed to reopen: \(error.localizedDescription)")
        }
    }

    func delItem(uid: String) -> R<String> {
        let log = Log.with("Reminder")
        log.d("Deleting reminder", more: ["uid": uid])
        
        guard let r = ek.calendarItem(withIdentifier: uid) as? EKReminder else {
            log.e("Not found")
            return .err("Reminder not found: \(uid)")
        }

        let t = r.title ?? "Untitled"
        do {
            try ek.remove(r, commit: true)
            log.i("Deleted", more: ["title": t])
            return .ok(uid)
        } catch {
            log.e("Failed to delete", more: ["err": error.localizedDescription])
            return .err("Failed to delete: \(error.localizedDescription)")
        }
    }

    // MARK: Helpers
    private func fmtReminder(_ r: EKReminder) -> ReminderInfo {
        var dueDate: Date?
        if let comp = r.dueDateComponents {
            dueDate = Calendar.current.date(from: comp)
        }
        
        return ReminderInfo(
            uid: r.calendarItemIdentifier,
            title: r.title ?? "",
            list: CalRef(
                uid: r.calendar?.calendarIdentifier ?? "",
                name: r.calendar?.title ?? ""
            ),
            isDone: r.isCompleted,
            doneAt: r.completionDate,
            due: dueDate,
            note: r.notes?.isEmpty == false ? r.notes : nil,
            link: r.url?.absoluteString,
            prio: r.priority
        )
    }
}
