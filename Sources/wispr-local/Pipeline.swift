import Foundation
import WisprLocalCore

enum Pipeline {
    static let cleanupTimeout: TimeInterval = 20
    static let silentPeak: Float = 0.01
    static let speechCheckTimeout: TimeInterval = 5

    /// Called each time text is sent to Claude, off the main thread.
    static var onClaude: () -> Void = {}

    /// Whether there is no speech. If the check can't run, only near-total silence counts.
    static func isSilent(_ samples: [Float]) -> Bool {
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("wispr-local-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: wav) }
        do {
            try WavEncoder.encode(samples).write(to: wav)
            let output = try run([Paths.tool("whisper-vad-speech-segments"), "-f", wav.path,
                                  "-vm", Paths.model(Paths.speechModelName).path,
                                  "-vt", SpeechCheck.threshold, "-vspd", SpeechCheck.minSpeechMs, "-np"],
                                 timeout: speechCheckTimeout)
            return SpeechCheck.isSilent(output)
        } catch {
            log("speech check failed, going by loudness: \(error)")
            return (samples.map(abs).max() ?? 0) < silentPeak
        }
    }

    /// Fast on-device cleanup first. Spoken corrections, and any edit that changed the words, go to Claude if it's
    /// installed and allowed; otherwise simple rules tidy the transcript.
    static func cleanUp(_ transcript: String, context: ScreenContext, allowClaude: Bool) -> String {
        if !allowClaude || !CleanupGuard.hasCorrection(transcript), let edited = OnDeviceCleaner.clean(transcript) {
            if CleanupGuard.isFaithful(edited, to: transcript) { return Disfluency.strip(edited) }
            log("on-device edit changed the words, not using it")
        }
        let fallback = Disfluency.strip(transcript)
        guard allowClaude else { return fallback }
        onClaude()
        do {
            let text = try claude(transcript, context: context)
            return CleanupGuard.isPlausible(text, for: transcript) ? text : fallback
        } catch {
            log("Claude cleanup unavailable, using simple rules: \(error)")
            return fallback
        }
    }

    /// Through the Claude Code CLI, so it needs no API key. MCP servers and tools are off: they double startup time.
    /// No session is saved, so dictations never land in Claude Code's history.
    private static func claude(_ transcript: String, context: ScreenContext) throws -> String {
        try run(["claude", "-p", "--model", "haiku", "--strict-mcp-config", "--tools", "", "--no-session-persistence"],
                stdin: Cleanup.prompt(transcript: transcript, context: context),
                cwd: FileManager.default.temporaryDirectory,
                timeout: cleanupTimeout)
    }
}
