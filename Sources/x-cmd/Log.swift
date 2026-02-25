import Foundation

enum LogLevel: String {
    case debug = "D"
    case info = "I"
    case warning = "W"
    case error = "E"
}

struct Log {
    static var minLevel: LogLevel = .info
    static var module: String = "macli"
    
    static func setLevel(_ level: LogLevel) {
        minLevel = level
    }
    
    private static func shouldLog(_ level: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        guard let minIndex = levels.firstIndex(of: minLevel),
              let levelIndex = levels.firstIndex(of: level) else {
            return false
        }
        return levelIndex >= minIndex
    }
    
    private static func needsBlockScalar(_ text: String) -> Bool {
        return text.contains("\n") || text.contains("\"") || text.contains(": ") || text.contains("|")
    }
    
    private static func formatValue(_ value: Any) -> String {
        let str = String(describing: value)
        if needsBlockScalar(str) {
            let lines = str.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count == 1 {
                return "|\n      " + lines[0]
            }
            return "|\n" + lines.map { "      " + $0 }.joined(separator: "\n")
        }
        return str
    }
    
    private static func output(_ level: LogLevel, subModule: String? = nil, message: String, more: [String: Any]? = nil) {
        guard shouldLog(level) else { return }
        
        var tag = module
        if let sub = subModule, !sub.isEmpty {
            tag = "\(module)/\(sub)"
        }
        
        var output = "- \(level.rawValue)|\(tag): "
        
        if needsBlockScalar(message) {
            let lines = message.split(separator: "\n", omittingEmptySubsequences: false)
            output += "|\n" + lines.map { "  \($0)" }.joined(separator: "\n")
        } else {
            output += message
        }
        
        if let more = more, !more.isEmpty {
            output += "\n  more:"
            for (key, value) in more {
                let formatted = formatValue(value)
                if formatted.hasPrefix("|") {
                    output += "\n    \(key): \(formatted)"
                } else {
                    output += "\n    \(key): \(formatted)"
                }
            }
        }
        
        if level == .error {
            FileHandle.standardError.write(Data((output + "\n").utf8))
        } else {
            print(output)
        }
    }
    
    static func d(_ message: String, subModule: String? = nil, more: [String: Any]? = nil) {
        output(.debug, subModule: subModule, message: message, more: more)
    }
    
    static func i(_ message: String, subModule: String? = nil, more: [String: Any]? = nil) {
        output(.info, subModule: subModule, message: message, more: more)
    }
    
    static func w(_ message: String, subModule: String? = nil, more: [String: Any]? = nil) {
        output(.warning, subModule: subModule, message: message, more: more)
    }
    
    static func e(_ message: String, subModule: String? = nil, more: [String: Any]? = nil) {
        output(.error, subModule: subModule, message: message, more: more)
    }
    
    static func with(_ subModule: String) -> LogHelper {
        return LogHelper(subModule: subModule)
    }
}

struct LogHelper {
    let subModule: String
    
    func d(_ message: String, more: [String: Any]? = nil) {
        Log.d(message, subModule: subModule, more: more)
    }
    
    func i(_ message: String, more: [String: Any]? = nil) {
        Log.i(message, subModule: subModule, more: more)
    }
    
    func w(_ message: String, more: [String: Any]? = nil) {
        Log.w(message, subModule: subModule, more: more)
    }
    
    func e(_ message: String, more: [String: Any]? = nil) {
        Log.e(message, subModule: subModule, more: more)
    }
}
