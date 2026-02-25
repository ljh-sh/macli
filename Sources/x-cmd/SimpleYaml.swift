import Foundation

enum SimpleYaml {
    static func parse(_ s: String) -> [String: Any]? {
        var result: [String: Any] = [:]
        let lines = s.components(separatedBy: .newlines)
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            guard !line.isEmpty else { i += 1; continue }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { i += 1; continue }
            
            if let colonIdx = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let afterColonStart = trimmed.index(after: colonIdx)
                let afterColon = trimmed.endIndex > afterColonStart
                    ? String(trimmed[afterColonStart...]).trimmingCharacters(in: .whitespaces)
                    : ""
                
                if afterColon.isEmpty {
                    i += 1
                    let (value, nextIdx) = parseValue(lines: lines, startIdx: i)
                    result[key] = value
                    i = nextIdx
                } else {
                    result[key] = afterColon
                    i += 1
                }
            } else {
                i += 1
            }
        }
        
        return result.isEmpty ? nil : result
    }
    
    private static func parseValue(lines: [String], startIdx: Int) -> (Any, Int) {
        var i = startIdx
        while i < lines.count {
            let line = lines[i]
            if line.isEmpty { i += 1; continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { i += 1; continue }
            break
        }
        
        guard i < lines.count else { return ([], i) }
        
        let firstLine = lines[i]
        let firstIndent = indentCount(firstLine)
        let firstTrimmed = firstLine.trimmingCharacters(in: .whitespaces)
        
        if firstTrimmed.hasPrefix("- ") || firstTrimmed == "-" {
            return parseList(lines: lines, startIdx: i, listIndent: firstIndent)
        } else {
            return parseDict(lines: lines, startIdx: i, dictIndent: firstIndent)
        }
    }
    
    private static func parseList(lines: [String], startIdx: Int, listIndent: Int) -> ([Any], Int) {
        var result: [Any] = []
        var i = startIdx
        
        while i < lines.count {
            let line = lines[i]
            if line.isEmpty { i += 1; continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { i += 1; continue }
            
            let currentIndent = indentCount(line)
            if currentIndent < listIndent { break }
            if currentIndent > listIndent { i += 1; continue }
            
            guard trimmed.hasPrefix("-") else { break }
            
            let afterDash = trimmed.count > 2 ? String(trimmed.dropFirst(2)) : ""
            
            if afterDash.isEmpty {
                i += 1
                if i < lines.count {
                    let (value, nextIdx) = parseValue(lines: lines, startIdx: i)
                    result.append(value)
                    i = nextIdx
                }
            } else if let colonIdx = afterDash.firstIndex(of: ":") {
                let key = String(afterDash[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let colonStart = afterDash.index(after: colonIdx)
                let valStr = afterDash.endIndex > colonStart
                    ? String(afterDash[colonStart...]).trimmingCharacters(in: .whitespaces)
                    : ""
                
                var itemDict: [String: Any] = [:]
                
                if valStr.isEmpty {
                    i += 1
                    if i < lines.count {
                        let nextLine = lines[i]
                        let nextIndent = indentCount(nextLine)
                        if nextIndent > currentIndent {
                            let (nestedValue, nextIdx) = parseDict(lines: lines, startIdx: i, dictIndent: nextIndent)
                            itemDict[key] = nestedValue
                            i = nextIdx
                        }
                    }
                    
                    while i < lines.count {
                        let nextLine = lines[i]
                        if nextLine.isEmpty { i += 1; continue }
                        let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                        if nextTrimmed.hasPrefix("#") { i += 1; continue }
                        
                        let nextIndent = indentCount(nextLine)
                        if nextIndent <= currentIndent { break }
                        if nextTrimmed.hasPrefix("-") { break }
                        
                        if let cIdx = nextTrimmed.firstIndex(of: ":") {
                            let k = String(nextTrimmed[..<cIdx]).trimmingCharacters(in: .whitespaces)
                            let colonStart2 = nextTrimmed.index(after: cIdx)
                            let v = nextTrimmed.endIndex > colonStart2
                                ? String(nextTrimmed[colonStart2...]).trimmingCharacters(in: .whitespaces)
                                : ""
                            
                            if v.isEmpty {
                                i += 1
                                let (nestedValue, nextIdx) = parseValue(lines: lines, startIdx: i)
                                itemDict[k] = nestedValue
                                i = nextIdx
                            } else {
                                itemDict[k] = v
                                i += 1
                            }
                        } else {
                            break
                        }
                    }
                } else {
                    itemDict[key] = valStr
                    i += 1
                }
                
                result.append(itemDict)
            } else {
                result.append(afterDash)
                i += 1
            }
        }
        
        return (result, i)
    }
    
    private static func parseDict(lines: [String], startIdx: Int, dictIndent: Int) -> ([String: Any], Int) {
        var result: [String: Any] = [:]
        var i = startIdx
        
        while i < lines.count {
            let line = lines[i]
            if line.isEmpty { i += 1; continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { i += 1; continue }
            
            let currentIndent = indentCount(line)
            if currentIndent < dictIndent { break }
            if currentIndent > dictIndent { i += 1; continue }
            if trimmed.hasPrefix("-") { break }
            
            guard let colonIdx = trimmed.firstIndex(of: ":") else { i += 1; continue }
            
            let key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let colonStart = trimmed.index(after: colonIdx)
            let afterColon = trimmed.endIndex > colonStart
                ? String(trimmed[colonStart...]).trimmingCharacters(in: .whitespaces)
                : ""
            
            if afterColon.isEmpty {
                i += 1
                let (value, nextIdx) = parseValue(lines: lines, startIdx: i)
                result[key] = value
                i = nextIdx
            } else {
                result[key] = afterColon
                i += 1
            }
        }
        
        return (result, i)
    }
    
    private static func indentCount(_ line: String) -> Int {
        var count = 0
        for c in line {
            if c == " " { count += 1 }
            else if c == "\t" { count += 2 }
            else { break }
        }
        return count
    }
    
    static func dump(_ data: [String: Any]) -> String {
        var result = ""
        dumpDict(data, to: &result, indent: 0)
        return result
    }
    
    private static func dumpDict(_ dict: [String: Any], to result: inout String, indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        for (k, v) in dict.sorted(by: { $0.key < $1.key }) {
            if let d = v as? [String: Any] {
                result += "\(prefix)\(k):\n"
                dumpDict(d, to: &result, indent: indent + 1)
            } else if let a = v as? [[String: Any]] {
                result += "\(prefix)\(k):\n"
                for item in a {
                    result += "\(prefix)  -\n"
                    dumpDict(item, to: &result, indent: indent + 2)
                }
            } else if let a = v as? [Any] {
                result += "\(prefix)\(k):\n"
                for item in a {
                    result += "\(prefix)  - \(formatValue(item))\n"
                }
            } else {
                result += "\(prefix)\(k): \(formatValue(v))\n"
            }
        }
    }
    
    private static func formatValue(_ v: Any) -> String {
        if v is NSNull { return "null" }
        if let b = v as? Bool { return b ? "true" : "false" }
        if let n = v as? Int { return String(n) }
        if let n = v as? Double { return String(n) }
        if let s = v as? String {
            if s.isEmpty || s.contains(":") || s.contains("#") || s.contains("\n") {
                return "\"\(s)\""
            }
            return s
        }
        if let d = v as? Date {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: d)
        }
        return String(describing: v)
    }
}
