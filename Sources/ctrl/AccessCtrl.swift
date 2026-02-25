import CoreLocation
import EventKit
import Foundation
import Speech

enum AccessErr: Error, LocalizedError {
    case denied(String)
    case fail(String)
    
    var errorDescription: String? {
        switch self {
        case .denied(let m), .fail(let m): return m
        }
    }
}

class AccessCtrl: NSObject, CLLocationManagerDelegate {
    private let ek: EKEventStore = Store.ek
    private let locMgr = CLLocationManager()
    private var locSem = DispatchSemaphore(value: 0)
    private var calGranted = false
    private var reminderGranted = false
    private var locGranted = false
    
    override init() {
        super.init()
        locMgr.delegate = self
        locMgr.desiredAccuracy = kCLLocationAccuracyBest
    }
    
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
    
    // MARK: Location
    func askLocation() throws {
        let log = Log.with("Access")
        log.d("Requesting location access")
        
        let s = locMgr.authorizationStatus
        if s == .authorized {
            log.i("Location access already granted")
            return
        }
        
        log.e("Denied")
        throw AccessErr.denied(
            "Location access required.\n\n" +
            "To grant:\n" +
            "1. Open System Settings > Privacy & Security > Location Services\n" +
            "2. Enable Location Services\n" +
            "3. Find and enable the app running macli\n\n" +
            "Note: CLI tools may not appear in Location Services.\n" +
            "For features that don't need current location:\n" +
            "  macli map geocode \"address\"\n" +
            "  macli map search \"place\"\n" +
            "  macli map directions \"from\" \"to\""
        )
    }
    
    // MARK: Speech
    func askSpeech() throws {
        let log = Log.with("Access")
        log.d("Requesting speech recognition access")
        
        let sem = DispatchSemaphore(value: 0)
        var auth = false
        
        SFSpeechRecognizer.requestAuthorization { s in
            auth = (s == .authorized)
            sem.signal()
        }
        sem.wait()
        
        if !auth {
            log.e("Denied")
            throw AccessErr.denied("Speech recognition permission denied. Grant in System Settings > Privacy > Speech Recognition.")
        }
        log.i("Speech recognition access granted")
    }
    
    // MARK: CLLocationManagerDelegate
    func locationManager(_ mgr: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        locSem.signal()
    }
    
    func locationManager(_ mgr: CLLocationManager, didFailWithError e: Error) {
        locSem.signal()
    }
}
