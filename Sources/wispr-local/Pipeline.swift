import Foundation
import WisprLocalCore

enum Pipeline {
    static let whisperTimeout: TimeInterval = 30
    static let cleanupTimeout: TimeInterval = 20

    /// Speech to text with whisper.cpp, running locally on the GPU.
    static func transcribe(_ wav: URL, model: URL, language: String) throws -> String {
        let output = try run(["whisper-cli", "-m", model.path, "-f", wav.path, "-l", language, "-nt", "-np"],
                             timeout: whisperTimeout)
        return Cleanup.normalizeTranscript(output)
    }

    /// The rewrite pass, through the Claude Code CLI so it needs no API key.
    /// MCP servers and tools are disabled: they load on every call and roughly double startup time.
    static func cleanUp(_ transcript: String, context: ScreenContext) throws -> String {
        try run(["claude", "-p", "--model", "haiku", "--strict-mcp-config", "--tools", ""],
                stdin: Cleanup.prompt(transcript: transcript, context: context),
                cwd: FileManager.default.temporaryDirectory,
                timeout: cleanupTimeout)
    }
}
