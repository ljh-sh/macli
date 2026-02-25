import Foundation

enum SpeechCmd: Cmd {
    static let meta = CmdMeta(
        name: "speech",
        desc: "Speech recognition",
        subcmds: [
            "recognize": SpeechRecognize.self,
            "langs": SpeechLangs.self,
        ]
    )
}

enum SpeechRecognize: Cmd {
    static let meta = CmdMeta(
        name: "recognize",
        desc: "Recognize speech from audio file",
        opts: [
            OptMeta(name: "--locale", desc: "Locale (en-US, zh-CN)", `default`: "en-US"),
        ],
        args: [ArgMeta(name: "file", desc: "Audio file path")],
        run: { p in
            let file: String = requireArg(p, 0, "File")
            let locale: String = p.opt("--locale") ?? "en-US"
            let acc = AccessCtrl(); try acc.askSpeech()
            let r = SpeechCtrl().recognize(path: file, locale: locale)
            print(x.json.stringify(r) { $0.toDict() })
        }
    )
}

enum SpeechLangs: Cmd {
    static let meta = CmdMeta(
        name: "langs",
        desc: "List supported languages",
        run: { _ in
            let r = SpeechCtrl().listLangs()
            print(x.json.stringify(r) { ["languages": $0.map { $0.toDict() }, "count": $0.count] })
        }
    )
}
