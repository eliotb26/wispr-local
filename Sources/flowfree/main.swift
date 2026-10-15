import AppKit
import AVFoundation

// flowfree: hold right Option, talk, let go. Text lands in the focused field.
//
//   swift run -c release flowfree              # with LLM cleanup
//   swift run -c release flowfree --raw        # whisper output only
//   swift run -c release flowfree --lang auto  # detect language

let rightOptionKeyCode: UInt16 = 61
let minRecordingSeconds: TimeInterval = 0.3

let args = CommandLine.arguments
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let config = Config(
    whisperModel: root.appendingPathComponent("models/ggml-large-v3-turbo-q5_0.bin"),
    cleanup: !args.contains("--raw"),
    language: args.firstIndex(of: "--lang").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "en"
)
let timingLog = root.appendingPathComponent("runs.csv")

final class Controller {
    private let recorder = Recorder()
    private let work = DispatchQueue(label: "flowfree.pipeline")
    private var context: ScreenContext?
    private var wav: URL?

    func keyDown() {
        guard recorder.startedAt == nil else { return }
        context = ScreenContext.capture()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("flowfree-\(UUID().uuidString).wav")
        do {
            try recorder.start(to: url)
            wav = url
            NSSound(named: "Tink")?.play()
        } catch {
            log("could not start recording: \(error)")
        }
    }

    func keyUp() {
        guard recorder.startedAt != nil, let wav, let context else { return }
        let seconds = recorder.stop()
        self.wav = nil
        guard seconds >= minRecordingSeconds else {
            try? FileManager.default.removeItem(at: wav)
            return
        }
        NSSound(named: "Pop")?.play()
        work.async { self.process(wav, seconds: seconds, context: context) }
    }

    private func process(_ wav: URL, seconds: TimeInterval, context: ScreenContext) {
        defer { try? FileManager.default.removeItem(at: wav) }
        let started = Date()
        do {
            let raw = try transcribe(wav, config: config)
            let asrMs = ms(since: started)
            guard !raw.isEmpty, raw != "[BLANK_AUDIO]" else { return log("heard nothing") }

            var text = raw
            var llmMs = 0
            let words = raw.split(separator: " ").count
            if config.cleanup && words >= Config.minWordsForCleanup {
                let llmStart = Date()
                do {
                    text = try cleanUp(raw, context: context)
                } catch {
                    log("cleanup failed, pasting raw transcript: \(error)")
                }
                llmMs = ms(since: llmStart)
            }

            DispatchQueue.main.async { Paster.paste(text) }
            let totalMs = ms(since: started)
            log("\(context.appName): \(String(format: "%.1f", seconds))s audio, \(words) words, asr \(asrMs)ms, llm \(llmMs)ms, total \(totalMs)ms")
            record(seconds: seconds, words: words, asrMs: asrMs, llmMs: llmMs, totalMs: totalMs, app: context.appName)
        } catch {
            log("failed: \(error)")
        }
    }
}

func ms(since date: Date) -> Int { Int(Date().timeIntervalSince(date) * 1000) }

func log(_ message: String) {
    FileHandle.standardError.write(Data("[flowfree] \(message)\n".utf8))
}

/// Timings only, never the text: these are the numbers for the write-up.
func record(seconds: TimeInterval, words: Int, asrMs: Int, llmMs: Int, totalMs: Int, app: String) {
    let isNew = !FileManager.default.fileExists(atPath: timingLog.path)
    let header = isNew ? "timestamp,audio_s,words,asr_ms,llm_ms,total_ms,app\n" : ""
    let row = "\(ISO8601DateFormatter().string(from: Date())),\(String(format: "%.2f", seconds)),\(words),\(asrMs),\(llmMs),\(totalMs),\"\(app)\"\n"
    guard let data = (header + row).data(using: .utf8) else { return }
    if isNew {
        FileManager.default.createFile(atPath: timingLog.path, contents: data)
    } else if let handle = try? FileHandle(forWritingTo: timingLog) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }
}

func checkPermissions() {
    let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    if !AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary) {
        log("grant Accessibility to your terminal app (System Settings > Privacy & Security > Accessibility), then restart")
    }
    AVCaptureDevice.requestAccess(for: .audio) { granted in
        if !granted { log("microphone access denied: allow it for your terminal app in System Settings") }
    }
}

guard FileManager.default.fileExists(atPath: config.whisperModel.path) else {
    log("model missing at \(config.whisperModel.path); run from the repo root")
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
checkPermissions()

let controller = Controller()
NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
    guard event.keyCode == rightOptionKeyCode else { return }
    if event.modifierFlags.contains(.option) { controller.keyDown() } else { controller.keyUp() }
}
log("ready. hold right Option to talk\(config.cleanup ? "" : " (raw mode, no cleanup)")")
app.run()
