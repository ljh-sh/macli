import EventKit
import Foundation

enum AccessErr: Error, LocalizedError {
    case denied(String)
    case fail(String)

    var errorDescription: String? {
        switch self {
        case .denied(let m), .fail(let m): return m
        }
    }
}

class AccessCtrl: NSObject {
    private let ek: EKEventStore = Store.ek
    private var calGranted = false
    private var reminderGranted = false

    // MARK: Calendar
    func askCal() throws {
        let log = Log.with("Access")
        log.d("Requesting calendar access")

        let sem = DispatchSemaphore(value: 0)
        var err: Error?

        if #available(macOS 14.0, *) {
            ek.requestFullAccessToEvents { ok, e in
                self.calGranted = ok
                err = e
                sem.signal()
            }
        } else {
            ek.requestAccess(to: .event) { ok, e in
                self.calGranted = ok
                err = e
                sem.signal()
            }
        }
        sem.wait()

        if let e = err {
            log.e("Error", more: ["err": e.localizedDescription])
            throw AccessErr.fail("Access error: \(e.localizedDescription)")
        }
        if !calGranted {
            log.e("Denied")
            throw AccessErr.denied("Calendar permission denied. Grant in System Settings > Privacy.")
        }
        log.i("Calendar access granted")
    }

    // MARK: Reminder
    func askReminder() throws {
        let log = Log.with("Access")
        log.d("Requesting reminder access")

        let sem = DispatchSemaphore(value: 0)
        var err: Error?

        if #available(macOS 14.0, *) {
            ek.requestFullAccessToReminders { ok, e in
                self.reminderGranted = ok
                err = e
                sem.signal()
            }
        } else {
            ek.requestAccess(to: .reminder) { ok, e in
                self.reminderGranted = ok
                err = e
                sem.signal()
            }
        }
        sem.wait()

        if let e = err {
            log.e("Error", more: ["err": e.localizedDescription])
            throw AccessErr.fail("Access error: \(e.localizedDescription)")
        }
        if !reminderGranted {
            log.e("Denied")
            throw AccessErr.denied("Reminder permission denied. Grant in System Settings > Privacy.")
        }
        log.i("Reminder access granted")
    }
}
