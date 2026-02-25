import Foundation

// MARK: Calendar Models

struct CalInfo {
    var uid: String
    var name: String
    var kind: String
    var src: String
    var color: String
    var canEdit: Bool
    var calType: String
    var isSubscribed: Bool
    var isImmutable: Bool
}

struct EventInfo {
    var uid: String
    var title: String
    var cal: CalRef
    var isAllDay: Bool
    var start: Date?
    var end: Date?
    var loc: String?
    var note: String?
    var link: String?
    var hasAlarm: Bool
    var hasRepeat: Bool
}

struct CalRef {
    var uid: String
    var name: String
}

// MARK: Reminder Models

struct ReminderList {
    var uid: String
    var name: String
    var src: String
    var color: String
    var canEdit: Bool
}

struct ReminderInfo {
    var uid: String
    var title: String
    var list: CalRef
    var isDone: Bool
    var doneAt: Date?
    var due: Date?
    var note: String?
    var link: String?
    var prio: Int
}

// MARK: Map Models

struct PlaceInfo {
    var name: String
    var addr: String?
    var lat: Double
    var lng: Double
}

struct RouteInfo {
    var dist: Double
    var dur: Double
    var steps: [RouteStep]
}

struct RouteStep {
    var instr: String
    var dist: Double
}

// MARK: Notify Models

struct NotifyInfo {
    var title: String
    var body: String
    var sound: Bool
    var scheduledAt: String?
}

// MARK: Speech Models

struct SpeechLang {
    var id: String
    var code: String
    var name: String
}

struct VoiceInfo {
    var id: String
    var name: String
    var lang: String
    var quality: Int
}

struct TranscriptInfo {
    var text: String
    var file: String
    var locale: String
    var isFinal: Bool
}

// MARK: Generic Result

enum R<T> {
    case ok(T)
    case err(String)
}
