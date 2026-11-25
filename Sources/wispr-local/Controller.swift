import AppKit
import WisprLocalCore

/// Owns one dictation at a time: key down starts recording, key up runs the pipeline.
/// keyDown, keyUp and cancel are called on the main thread; the pipeline runs on a serial queue.
final class Controller {
    static let minRecordingSeconds: TimeInterval = 0.3
    static let liveInterval: TimeInterval = 0.8
    static let liveWindowSeconds = 12.0

    var onRecordingChange: (Bool) -> Void = { _ in }
    var onLevel: (Float) -> Void = { _ in }
    var onWords: (String) -> Void = { _ in }
    /// Final touches chosen by the user: style, then snippets. Called on the pipeline queue.
    var finish: (String, String) -> String = { text, _ in text }
    var onResult: (Dictation, [Float]) -> Void = { _, _ in }
    /// Returns where the recording should go instead of being typed, e.g. the voice test.
    var captureTarget: () -> (([Float]) -> Void)? = { nil }
    var canRetry: Bool {
        guard let job = retryJob else { return false }
        return Date().timeIntervalSince(job.date) < Self.retryLifetime
            && NSWorkspace.shared.frontmostApplication?.localizedName == job.context.appName
    }

    func forgetLast() { retryJob = nil }

    private struct Job {
        let date = Date()
        let samples: [Float]
        let seconds: TimeInterval
        let context: ScreenContext
        let isSecure: Bool
    }
    private var capture: (([Float]) -> Void)?
    private var retryJob: Job? // only for retryLifetime, and only in the app it was spoken into
    private static let retryLifetime: TimeInterval = 600
    private var joiner = Joiner()
    private var isSecure = false

    private let options: Options
    private let server: WhisperServer
    private let timingLog: TimingLog
    private let recorder = Recorder()
    private let pill = Pill()
    private let work = DispatchQueue(label: "wispr-local.pipeline")
    private let live = DispatchQueue(label: "wispr-local.live")
    private var context: ScreenContext?
    private var liveTimer: Timer?
    private var liveBusy = false
    private var session = 0

    init(options: Options, server: WhisperServer, timingLog: TimingLog) {
        self.options = options
        self.server = server
        self.timingLog = timingLog
        recorder.onLevel = { [weak self] in
            self?.pill.setLevel($0)
            self?.onLevel($0)
        }
    }

    private var allowClaude: Bool { options.allowClaude && (!Paths.isApp || Settings.useClaude) }

    func keyDown() {
        guard !recorder.isRecording else { return }
        do {
            try recorder.start() // first, so slow apps can't cost us the opening words
            context = ScreenContext.capture(includeField: options.cleanup && allowClaude)
            isSecure = ScreenContext.isSecureField()
            capture = captureTarget()
            session += 1
            pill.listening()
            onRecordingChange(true)
            if capture == nil && !isSecure { startLiveWords() }
        } catch {
            log("could not start recording: \(error)")
            pill.error("Can't use the microphone")
        }
    }

    func keyUp() {
        guard recorder.isRecording, let context else { return }
        let (samples, seconds) = endRecording()
        guard seconds >= Self.minRecordingSeconds else { return pill.hide() }
        if let capture {
            pill.hide()
            return capture(samples)
        }
        if Settings.playSound { NSSound(named: "Pop")?.play() }
        pill.working()
        let current = session
        let job = Job(samples: samples, seconds: seconds, context: context, isSecure: isSecure)
        work.async { self.process(job, session: current) }
    }

    /// The user typed or clicked, so the next dictation doesn't continue the last one.
    func userActed() { joiner.userActed() }

    /// Throws away the current recording.
    func cancel() {
        guard recorder.isRecording else { return }
        _ = endRecording()
        pill.hide()
    }

    private func endRecording() -> (samples: [Float], seconds: TimeInterval) {
        liveTimer?.invalidate()
        let result = recorder.stop()
        onRecordingChange(false)
        return result
    }

    /// Shows the latest words in the pill. They are only a preview: the pasted text uses the whole recording.
    private func startLiveWords() {
        let current = session
        liveTimer = Timer.scheduledTimer(withTimeInterval: Self.liveInterval, repeats: true) { [weak self] _ in
            guard let self, !self.liveBusy else { return }
            self.liveBusy = true
            let samples = self.recorder.snapshot(last: Self.liveWindowSeconds)
            self.live.async {
                let text = Pipeline.isSilent(samples) ? nil : try? self.server.preview(samples)
                DispatchQueue.main.async {
                    self.liveBusy = false
                    guard let text, current == self.session, !Cleanup.isEmptyTranscript(text) else { return }
                    self.pill.setWords(text)
                    self.onWords(text)
                }
            }
        }
    }

    /// Runs the last dictation that produced nothing again, skipping the speech check.
    func retryLast() {
        guard canRetry, let job = retryJob, !recorder.isRecording else { return }
        retryJob = nil
        session += 1
        pill.working()
        let current = session
        work.async { self.process(job, session: current, checkSpeech: false) }
    }

    private func process(_ job: Job, session: Int, checkSpeech: Bool = true) {
        let started = Date()
        do {
            if checkSpeech && Pipeline.isSilent(job.samples) { return nothing(job, .silent, "No speech found", session) }
            let transcript = try server.transcribe(job.samples)
            let asrMs = milliseconds(since: started)
            guard !Cleanup.isEmptyTranscript(transcript) else { return nothing(job, .silent, "No words found", session) }

            let cleanStart = Date()
            let shouldClean = Cleanup.shouldClean(transcript, enabled: options.cleanup)
            let cleaned = shouldClean ? Pipeline.cleanUp(transcript, context: job.context, allowClaude: allowClaude && !job.isSecure) : transcript
            let text = job.isSecure ? cleaned : finish(cleaned, job.context.appName)
            let llmMs = shouldClean ? milliseconds(since: cleanStart) : 0
            let totalMs = milliseconds(since: started)
            let entry = Dictation(date: Date(), seconds: job.seconds, app: job.context.appName, outcome: .typed,
                                  text: text, heard: transcript, totalMs: totalMs)
            DispatchQueue.main.async {
                self.retryJob = nil
                let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
                Paster.paste(job.isSecure ? text : self.joiner.join(text, app: app, at: Date()))
                self.report(entry, job)
            }
            finish(session)

            let record = TimingRecord(date: Date(), audioSeconds: job.seconds, words: Cleanup.wordCount(transcript),
                                      asrMs: asrMs, llmMs: llmMs, totalMs: totalMs, app: job.context.appName)
            log("\(record.app): \(String(format: "%.1f", job.seconds))s audio, \(record.words) words, asr \(asrMs)ms, llm \(llmMs)ms, total \(record.totalMs)ms")
            guard !Paths.isApp || Settings.retention != .off else { return }
            do { try timingLog.append(record) } catch { log("could not write timing log: \(error)") }
        } catch {
            log("failed: \(error)")
            nothing(job, .failed, "Couldn't transcribe that", session)
        }
    }

    /// Records a dictation that typed nothing, and keeps it for Retry.
    private func nothing(_ job: Job, _ outcome: Dictation.Outcome, _ problem: String, _ session: Int) {
        log("\(job.context.appName): \(String(format: "%.1f", job.seconds))s audio, \(problem.lowercased())")
        let entry = Dictation(date: Date(), seconds: job.seconds, app: job.context.appName, outcome: outcome, problem: problem)
        DispatchQueue.main.async {
            self.retryJob = job.isSecure ? nil : job
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryLifetime) { [weak self] in
                if self?.retryJob?.date == job.date { self?.retryJob = nil }
            }
            self.report(entry, job)
        }
        finish(session, error: outcome == .failed ? problem : nil)
    }

    private func report(_ entry: Dictation, _ job: Job) {
        if job.isSecure { return log("not saved: a password field was in use") }
        onResult(entry, job.samples)
    }

    /// Clears the pill, unless a newer dictation already owns it.
    private func finish(_ finished: Int, error: String? = nil) {
        DispatchQueue.main.async {
            guard finished == self.session, !self.recorder.isRecording else { return }
            if let error { self.pill.error(error) } else { self.pill.hide() }
        }
    }
}

func milliseconds(since date: Date) -> Int {
    Int(Date().timeIntervalSince(date) * 1000)
}
