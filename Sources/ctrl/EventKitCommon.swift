import CoreGraphics
import EventKit
import Foundation

enum EKErr: Error, LocalizedError {
    case denied(String)
    case fail(String)
    case notFound(String)
    case noEdit(String)
    case saveFail(String)
    case delFail(String)
    
    var errorDescription: String? {
        switch self {
        case .denied(let m), .fail(let m), .notFound(let m),
             .noEdit(let m), .saveFail(let m), .delFail(let m):
            return m
        }
    }
}

enum Store {
    static let ek = EKEventStore()
}

func fmtDate(_ d: Date?) -> String? {
    guard let d = d else { return nil }
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
    f.timeZone = TimeZone.current
    return f.string(from: d)
}
