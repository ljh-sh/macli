import AVFoundation
import Foundation
import Speech

enum SpeechErr: Error, LocalizedError {
    case notAvail(String)
    case timeout(String)
    case fail(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvail(let m), .timeout(let m), .fail(let m): return m
        }
    }
}

class SpeechCtrl {
    // MARK: List Languages
    func listLangs() -> R<[SpeechLang]> {
        let log = Log.with("Speech")
        log.d("Listing speech languages")
        
        let locales = SFSpeechRecognizer.supportedLocales()
        let langs = locales.map { l in
            SpeechLang(
                id: l.identifier,
                code: l.languageCode ?? "",
                name: Locale.current.localizedString(forIdentifier: l.identifier) ?? ""
            )
        }.sorted { $0.id < $1.id }

        log.i("Listed languages", more: ["count": langs.count])
        return .ok(langs)
    }

    // MARK: Recognize Audio
    func recognize(path: String, locale: String = "en-US") -> R<TranscriptInfo> {
        let log = Log.with("Speech")
        log.d("Recognizing audio", more: ["path": path, "locale": locale])
        
        let url = URL(fileURLWithPath: path)

        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            log.e("Recognizer not available", more: ["locale": locale])
            return .err("Recognizer not available for: \(locale)")
        }

        guard rec.isAvailable else {
            log.e("Recognizer unavailable")
            return .err("Speech recognizer is not available")
        }

        let req = SFSpeechURLRecognitionRequest(url: url)
        let sem = DispatchSemaphore(value: 0)
        var txt = ""
        var isFin = false
        var err: Error?

        rec.recognitionTask(with: req) { r, e in
            if let e = e {
                err = e
                sem.signal()
                return
            }
            if let r = r {
                txt = r.bestTranscription.formattedString
                isFin = r.isFinal
                if r.isFinal { sem.signal() }
            }
        }

        let r = sem.wait(timeout: .now() + 60)
        if r == .timedOut {
            log.w("Timeout")
            return .err("Recognition timed out")
        }

        if let e = err {
            log.e("Failed", more: ["err": e.localizedDescription])
            return .err("Recognition failed: \(e.localizedDescription)")
        }

        log.i("Done", more: ["text": txt])
        return .ok(TranscriptInfo(text: txt, file: path, locale: locale, isFinal: isFin))
    }

    // MARK: Text to Speech
    func speak(text: String, voice: String? = nil, rate: Float = 0.5) -> R<String> {
        let log = Log.with("Speak")
        log.d("Speaking", more: ["voice": voice ?? "default", "rate": rate])
        
        let utt = AVSpeechUtterance(string: text)
        utt.voice = voice != nil 
            ? AVSpeechSynthesisVoice(identifier: voice!) 
            : AVSpeechSynthesisVoice(language: "en-US")
        utt.rate = rate

        let syn = AVSpeechSynthesizer()
        syn.speak(utt)

        log.i("Speech started")
        return .ok(text)
    }

    // MARK: List Voices
    func listVoices() -> R<[VoiceInfo]> {
        let log = Log.with("Speak")
        log.d("Listing voices")
        
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let list = voices.map { v in
            VoiceInfo(id: v.identifier, name: v.name, lang: v.language, quality: v.quality.rawValue)
        }

        log.i("Listed voices", more: ["count": list.count])
        return .ok(list)
    }
}
