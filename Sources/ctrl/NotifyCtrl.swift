import Foundation

class NotifyCtrl {
    // MARK: Send
    func send(title: String, body: String, sound: Bool = true) -> R<NotifyInfo> {
        let log = Log.with("Notify")
        log.d("Sending notification", more: ["title": title, "sound": sound])
        
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        n.soundName = sound ? NSUserNotificationDefaultSoundName : nil

        NSUserNotificationCenter.default.deliver(n)

        log.i("Sent", more: ["title": title])
        return .ok(NotifyInfo(title: title, body: body, sound: sound))
    }

    // MARK: Schedule
    func schedule(title: String, body: String, at date: Date) -> R<NotifyInfo> {
        let log = Log.with("Notify")
        log.d("Scheduling", more: ["title": title, "at": ISO8601DateFormatter().string(from: date)])
        
        let now = Date()
        guard date > now else {
            log.w("Must be future")
            return .err("Schedule time must be in the future")
        }

        let delay = date.timeIntervalSince(now)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            self.emit(title: title, body: body, sound: true)
        }

        log.i("Scheduled", more: ["title": title])
        return .ok(NotifyInfo(
            title: title,
            body: body,
            sound: true,
            scheduledAt: ISO8601DateFormatter().string(from: date)
        ))
    }

    private func emit(title: String, body: String, sound: Bool) {
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        n.soundName = sound ? NSUserNotificationDefaultSoundName : nil
        NSUserNotificationCenter.default.deliver(n)
    }
}
