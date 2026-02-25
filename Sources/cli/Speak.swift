import Foundation

enum SpeakCmd: Cmd {
    static let meta = CmdMeta(
        name: "speak",
        desc: "Text to speech",
        subcmds: [
            "text": SpeakText.self,
            "voices": SpeakVoices.self,
        ]
    )
}

enum SpeakText: Cmd {
    static let meta = CmdMeta(
        name: "text",
        desc: "Speak text",
        opts: [
            OptMeta(name: "--voice", desc: "Voice identifier"),
            OptMeta(name: "--rate", type: Double.self, desc: "Rate (0.0-1.0)"),
        ],
        args: [ArgMeta(name: "text")],
        run: { p in
            let text: String = requireArg(p, 0, "Text")
            let voice: String? = p.opt("--voice")
            let rate: Double = p.opt("--rate") ?? 0.5
            let r = SpeechCtrl().speak(text: text, voice: voice, rate: Float(rate))
            print(x.json.stringify(r) { ["text": $0] })
        }
    )
}

enum SpeakVoices: Cmd {
    static let meta = CmdMeta(
        name: "voices",
        desc: "List available voices",
        run: { _ in
            let r = SpeechCtrl().listVoices()
            print(x.json.stringify(r) { ["voices": $0.map { $0.toDict() }, "count": $0.count] })
        }
    )
}
