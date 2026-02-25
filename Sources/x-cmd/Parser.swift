import Foundation

struct Parser {
    private var args: [String]
    private var idx = 0
    
    init(_ args: [String]) {
        self.args = args
    }
    
    var isEmpty: Bool { idx >= args.count }
    var current: String? { idx < args.count ? args[idx] : nil }
    
    mutating func opt(_ name: String) -> String? {
        guard idx < args.count, args[idx] == name, idx + 1 < args.count else { return nil }
        idx += 2
        return args[idx - 1]
    }
    
    mutating func optInt(_ name: String) -> Int? {
        guard let v = opt(name) else { return nil }
        return Int(v)
    }
    
    mutating func optDouble(_ name: String) -> Double? {
        guard let v = opt(name) else { return nil }
        return Double(v)
    }
    
    mutating func flag(_ name: String) -> Bool {
        guard idx < args.count, args[idx] == name else { return false }
        idx += 1
        return true
    }
    
    mutating func arg() -> String? {
        guard idx < args.count else { return nil }
        defer { idx += 1 }
        return args[idx]
    }
    
    mutating func remainingArgs() -> [String] {
        let r = Array(args[idx...])
        idx = args.count
        return r
    }
}

typealias x = XCMD
