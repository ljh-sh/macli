import Foundation

@main
enum Macli {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        do {
            try runCmd(MacliRoot.self, args)
        } catch {
            print(x.json.stringify(["ok": false, "error": error.localizedDescription]))
            exit(1)
        }
    }
}

enum MacliRoot: Cmd {
    static let meta = CmdMeta(
        name: "macli",
        desc: "macOS system tools CLI",
        subcmds: [
            "cal": CalCmd.self,
            "event": EventCmd.self,
            "reminder": ReminderCmd.self,
            "aka": AkaCmd.self,
            "map": MapCmd.self,
            "location": LocationCmd.self,
            "notify": NotifyCmd.self,
            "speech": SpeechCmd.self,
            "speak": SpeakCmd.self,
            "smc": SmcCmd.self,
            "smc86": Smc86Cmd.self,
        ]
    )
}
