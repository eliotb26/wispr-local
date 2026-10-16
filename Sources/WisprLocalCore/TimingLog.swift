import Foundation

/// One dictation's timings. Never holds the dictated text.
public struct TimingRecord: Equatable, Sendable {
    public let date: Date
    public let audioSeconds: TimeInterval
    public let words: Int
    public let asrMs: Int
    public let llmMs: Int
    public let totalMs: Int
    public let app: String

    public init(date: Date, audioSeconds: TimeInterval, words: Int, asrMs: Int, llmMs: Int, totalMs: Int, app: String) {
        self.date = date
        self.audioSeconds = audioSeconds
        self.words = words
        self.asrMs = asrMs
        self.llmMs = llmMs
        self.totalMs = totalMs
        self.app = app
    }

    public static let csvHeader = "timestamp,audio_s,words,asr_ms,llm_ms,total_ms,app"

    public var csvRow: String {
        let timestamp = ISO8601DateFormatter().string(from: date)
        let escapedApp = app.replacingOccurrences(of: "\"", with: "\"\"")
        return [timestamp, String(format: "%.2f", audioSeconds), "\(words)", "\(asrMs)", "\(llmMs)", "\(totalMs)", "\"\(escapedApp)\""]
            .joined(separator: ",")
    }
}

/// Appends timing rows to a CSV file, writing the header on first use.
public struct TimingLog: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func append(_ record: TimingRecord) throws {
        let manager = FileManager.default
        if !manager.fileExists(atPath: url.path) {
            try Data((TimingRecord.csvHeader + "\n").utf8).write(to: url)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((record.csvRow + "\n").utf8))
    }
}
