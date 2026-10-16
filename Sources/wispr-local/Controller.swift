import AppKit
import WisprLocalCore

/// Owns one dictation at a time: key down starts recording, key up runs the pipeline.
/// keyDown/keyUp are called on the main thread; the pipeline runs on a serial queue.
final class Controller {
    static let minRecordingSeconds: TimeInterval = 0.3

    private let options: Options
    private let model: URL
    private let timingLog: TimingLog
    private let recorder = Recorder()
    private let work = DispatchQueue(label: "wispr-local.pipeline")
    private var pending: (wav: URL, context: ScreenContext)?

    init(options: Options, model: URL, timingLog: TimingLog) {
        self.options = options
        self.model = model
        self.timingLog = timingLog
    }

    func keyDown() {
        guard !recorder.isRecording else { return }
        let context = ScreenContext.capture()
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("wispr-local-\(UUID().uuidString).wav")
        do {
            try recorder.start(to: wav)
            pending = (wav, context)
            NSSound(named: "Tink")?.play()
        } catch {
            log("could not start recording: \(error)")
        }
    }

    func keyUp() {
        guard recorder.isRecording, let (wav, context) = pending else { return }
        pending = nil
        let seconds = recorder.stop()
        guard seconds >= Self.minRecordingSeconds else {
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
            let transcript = try Pipeline.transcribe(wav, model: model, language: options.language)
            let asrMs = milliseconds(since: started)
            guard !Cleanup.isEmptyTranscript(transcript) else { return log("heard nothing") }

            let (text, llmMs) = clean(transcript, context: context)
            DispatchQueue.main.async { Paster.paste(text) }

            let record = TimingRecord(date: Date(), audioSeconds: seconds, words: Cleanup.wordCount(transcript),
                                      asrMs: asrMs, llmMs: llmMs, totalMs: milliseconds(since: started), app: context.appName)
            log("\(record.app): \(String(format: "%.1f", seconds))s audio, \(record.words) words, asr \(asrMs)ms, llm \(llmMs)ms, total \(record.totalMs)ms")
            do { try timingLog.append(record) } catch { log("could not write timing log: \(error)") }
        } catch {
            log("failed: \(error)")
        }
    }

    /// Returns the cleaned text, or the raw transcript if cleanup is off, skipped or fails.
    private func clean(_ transcript: String, context: ScreenContext) -> (text: String, ms: Int) {
        guard Cleanup.shouldClean(transcript, enabled: options.cleanup) else { return (transcript, 0) }
        let started = Date()
        do {
            return (try Pipeline.cleanUp(transcript, context: context), milliseconds(since: started))
        } catch {
            log("cleanup failed, pasting raw transcript: \(error)")
            return (transcript, milliseconds(since: started))
        }
    }
}

func milliseconds(since date: Date) -> Int {
    Int(Date().timeIntervalSince(date) * 1000)
}

func log(_ message: String) {
    FileHandle.standardError.write(Data("[wispr-local] \(message)\n".utf8))
}
