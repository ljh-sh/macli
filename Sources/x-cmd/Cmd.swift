import Foundation

struct CmdMeta {
    var name: String
    var alias: [String] = []
    var desc: String = ""
    var opts: [OptMeta] = []
    var args: [ArgMeta] = []
    var subcmds: [String: Cmd.Type] = [:]
    var run: ((ParsedCmd) throws -> Void)?
}

struct OptMeta {
    var name: String
    var alias: String?
    var type: Any.Type = String.self
    var desc: String = ""
    var required: Bool = false
    var `default`: Any?
}

struct ArgMeta {
    var name: String
    var desc: String = ""
    var required: Bool = true
    var variadic: Bool = false
}

struct TldrItem {
    var desc: String
    var cmd: String
}

struct ParsedCmd {
    var opts: [String: Any] = [:]
    var args: [String] = []
    
    func opt<T>(_ name: String) -> T? {
        opts[name] as? T
    }
    
    func opt<T>(_ name: String, _ alias: String) -> T? {
        opts[name] as? T ?? opts[alias] as? T
    }
    
    func arg(_ idx: Int) -> String? {
        idx < args.count ? args[idx] : nil
    }
}

protocol Cmd {
    static var meta: CmdMeta { get }
    static func getTLDR() -> [TldrItem]?
}

extension Cmd {
    static func getTLDR() -> [TldrItem]? { nil }
}

func runCmd(_ type: Cmd.Type, _ args: [String]) throws {
    let meta = type.meta
    
    if args.first == "--help" || args.first == "-h" {
        printCmdHelp(type)
        return
    }
    
    var parsed = ParsedCmd()
    var remaining = args
    var i = 0
    
    while i < remaining.count {
        let a = remaining[i]
        
        if let subcmdType = meta.subcmds[a] ?? meta.subcmds.values.first(where: { $0.meta.alias.contains(a) }) {
            try runCmd(subcmdType, Array(remaining.dropFirst(i + 1)))
            return
        }
        
        if a.hasPrefix("-") {
            let optName: String
            let explicitValue: String?
            if a.hasPrefix("--"), let eqIdx = a.firstIndex(of: "=") {
                optName = String(a[..<eqIdx])
                explicitValue = String(a[a.index(after: eqIdx)...])
            } else {
                optName = a
                explicitValue = nil
            }
            if let optMeta = meta.opts.first(where: { $0.name == optName || $0.alias == optName }) {
                if optMeta.type is Bool.Type {
                    parsed.opts[optMeta.name] = true
                } else {
                    let raw: String
                    if let v = explicitValue {
                        raw = v
                    } else {
                        i += 1
                        guard i < remaining.count else { cmdError("missing value for \(optName)") }
                        raw = remaining[i]
                        // Disambiguate: a value that starts with `-` is the next flag, not our value.
                        if raw.hasPrefix("-") {
                            if optMeta.type is Int.Type && Int(raw) != nil {
                                // negative integer literal is allowed
                            } else if optMeta.type is Double.Type && Double(raw) != nil {
                                // negative number literal is allowed
                            } else {
                                cmdError("missing value for \(optName)")
                            }
                        }
                    }
                    if optMeta.type is Int.Type {
                        guard let v = Int(raw) else { cmdError("\(optName) requires an integer value") }
                        parsed.opts[optMeta.name] = v
                    } else if optMeta.type is Double.Type {
                        guard let v = Double(raw) else { cmdError("\(optName) requires a numeric value") }
                        parsed.opts[optMeta.name] = v
                    } else {
                        parsed.opts[optMeta.name] = raw
                    }
                }
            }
        } else {
            parsed.args.append(a)
        }
        i += 1
    }
    
    if let handler = meta.run {
        try handler(parsed)
    } else if !meta.subcmds.isEmpty {
        printCmdHelp(type)
    }
}

enum C {
    static var enabled: Bool = isatty(STDOUT_FILENO) != 0
    static let reset = "\u{001B}[0m"
    static let boldCode = "\u{001B}[1m"
    static let dimCode = "\u{001B}[2m"
    static let cyanCode = "\u{001B}[36m"
    static let yellowCode = "\u{001B}[33m"
    static let greenCode = "\u{001B}[32m"
    static let blueCode = "\u{001B}[34m"
    
    static func bold(_ s: String) -> String { enabled ? boldCode + s + reset : s }
    static func green(_ s: String) -> String { enabled ? greenCode + s + reset : s }
    static func yellow(_ s: String) -> String { enabled ? yellowCode + s + reset : s }
    static func cyan(_ s: String) -> String { enabled ? cyanCode + s + reset : s }
    static func dim(_ s: String) -> String { enabled ? dimCode + s + reset : s }
}

func printCmdHelp(_ type: Cmd.Type) {
    let meta = type.meta
    let name = meta.name == "macli" ? "macli" : "macli \(meta.name)"
    
    print(C.bold("NAME:"))
    print("    \(C.green(name))")
    print("")
    
    if !meta.desc.isEmpty {
        print(C.bold("DESCRIPTION:"))
        print("    \(meta.desc)")
        print("")
    }
    
    if let tldrItems = type.getTLDR(), !tldrItems.isEmpty {
        print(C.bold("TLDR:"))
        for item in tldrItems {
            print("    \(C.cyan("# " + item.desc))")
            print("    \(C.yellow(item.cmd))")
        }
        print("")
    }
    
    if !meta.subcmds.isEmpty {
        print(C.bold("SUBCOMMANDS:"))
        for (name, subType) in meta.subcmds.sorted(by: { $0.key < $1.key }) {
            let subMeta = subType.meta
            var aliases = ""
            if !subMeta.alias.isEmpty {
                aliases = C.dim("|") + subMeta.alias.map { C.green($0) }.joined(separator: C.dim("|"))
            }
            let cmdLine = "    " + C.green(name) + aliases
            print("\(cmdLine.pad(24))\(subMeta.desc)")
        }
        print("")
    }
    
    if !meta.opts.isEmpty {
        print(C.bold("OPTIONS:"))
        for opt in meta.opts {
            let alias = opt.alias.map { " " + C.dim("|") + " " + C.yellow($0) } ?? ""
            let line = "    " + C.yellow(opt.name) + alias
            print("\(line.pad(28))\(opt.desc)")
        }
        print("")
    }
    
    if !meta.args.isEmpty {
        print(C.bold("ARGUMENTS:"))
        for arg in meta.args {
            let req = arg.required ? "" : "?"
            print("    <\(arg.name)>\(req)".pad(28) + arg.desc)
        }
        print("")
    }
}

extension String {
    func pad(_ len: Int) -> String {
        let stripped = self.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
        let visualLen = stripped.count
        if visualLen >= len { return self }
        return self + String(repeating: " ", count: len - visualLen)
    }
}

func cmdError(_ msg: String) -> Never {
    print(x.json.stringify(["ok": false, "error": msg]))
    exit(1)
}

func requireArg(_ p: ParsedCmd, _ idx: Int, _ name: String) -> String {
    guard let v = p.arg(idx) else { cmdError("\(name) required") }
    return v
}

func requireOpt<T>(_ p: ParsedCmd, _ name: String) -> T {
    guard let v: T = p.opt(name) else { cmdError("\(name) required") }
    return v
}
