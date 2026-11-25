import Foundation

/// One dictation, as kept in the history on this Mac.
public struct Dictation: Codable, Equatable, Identifiable, Sendable {
    public enum Outcome: String, Codable, Sendable { case typed, silent, failed }

    public let id: UUID
    public let date: Date
    public let seconds: TimeInterval
    public let app: String
    public let outcome: Outcome
    /// What was typed.
    public let text: String
    /// What whisper heard, before cleanup.
    public let heard: String
    /// The user's correction, if they fixed it.
    public let corrected: String?
    /// Why it failed, if it did.
    public let problem: String?
    public let totalMs: Int

    public init(id: UUID = UUID(), date: Date, seconds: TimeInterval, app: String, outcome: Outcome, text: String = "",
                heard: String = "", corrected: String? = nil, problem: String? = nil, totalMs: Int = 0) {
        self.id = id
        self.date = date
        self.seconds = seconds
        self.app = app
        self.outcome = outcome
        self.text = text
        self.heard = heard
        self.corrected = corrected
        self.problem = problem
        self.totalMs = totalMs
    }

    public var finalText: String { corrected ?? text }

    /// A copy holding the user's fix; blank or unchanged text clears it.
    public func correcting(to fix: String) -> Dictation {
        let trimmed = fix.trimmingCharacters(in: .whitespacesAndNewlines)
        return Dictation(id: id, date: date, seconds: seconds, app: app, outcome: outcome, text: text, heard: heard,
                         corrected: trimmed.isEmpty || trimmed == text ? nil : trimmed, problem: problem, totalMs: totalMs)
    }

    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.isEmpty || [finalText, app].contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

/// How long history stays on this Mac.
public enum Retention: String, CaseIterable, Sendable {
    case off, day, month, forever

    public var label: String {
        switch self {
        case .off: return "Don't save"
        case .day: return "24 hours"
        case .month: return "30 days"
        case .forever: return "Until I delete it"
        }
    }

    private var maxAge: TimeInterval? {
        switch self {
        case .off: return 0
        case .day: return 86_400
        case .month: return 30 * 86_400
        case .forever: return nil
        }
    }

    /// The entries still allowed to be kept.
    public func keep(_ entries: [Dictation], now: Date) -> [Dictation] {
        guard let maxAge else { return entries }
        return entries.filter { now.timeIntervalSince($0.date) < maxAge }
    }
}

/// Totals for the summary line.
public struct DictationStats: Equatable, Sendable {
    public let words: Int
    public let wordsPerMinute: Int
    public let medianMs: Int

    public init(_ entries: [Dictation]) {
        let typed = entries.filter { $0.outcome == .typed }
        let heardWords = typed.reduce(0) { $0 + Cleanup.wordCount($1.heard) }
        let minutes = typed.reduce(0) { $0 + $1.seconds } / 60
        words = typed.reduce(0) { $0 + Cleanup.wordCount($1.finalText) }
        wordsPerMinute = minutes > 0 ? Int((Double(heardWords) / minutes).rounded()) : 0
        medianMs = typed.isEmpty ? 0 : typed.map(\.totalMs).sorted()[typed.count / 2]
    }
}

/// History in one JSON Lines file only this user can read. Not thread safe: use it from one thread.
public struct HistoryFile: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    /// Oldest first. Lines that can't be read are skipped, so one bad line can't hide the rest.
    public func load() throws -> [Dictation] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let decoder = JSONDecoder()
        return try Data(contentsOf: url).split(separator: UInt8(ascii: "\n")).compactMap { try? decoder.decode(Dictation.self, from: $0) }
    }

    public func append(_ entry: Dictation) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return try save([entry]) }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        // A line cut short by a crash must not swallow this one.
        if end > 0 { try handle.seek(toOffset: end - 1) }
        let lastByte = try handle.read(upToCount: 1)
        let needsNewline = end > 0 && lastByte != Data("\n".utf8)
        try handle.write(contentsOf: (needsNewline ? Data("\n".utf8) : Data()) + Self.line(entry))
    }

    public func save(_ entries: [Dictation]) throws {
        try entries.map(Self.line).reduce(Data(), +).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func line(_ entry: Dictation) throws -> Data {
        try JSONEncoder().encode(entry) + Data("\n".utf8)
    }
}

/// Decides whether a dictation continues the one before it, so the two need a space between them.
public struct Joiner: Sendable {
    public static let maxGap: TimeInterval = 120
    private var lastApp: String?
    private var lastDate = Date.distantPast

    public init() {}

    /// Typing or clicking means the cursor may have moved.
    public mutating func userActed() { lastApp = nil }

    /// The text to paste, with a leading space when it follows straight on.
    public mutating func join(_ text: String, app: String, at date: Date) -> String {
        defer { (lastApp, lastDate) = (app, date) }
        return lastApp == app && date.timeIntervalSince(lastDate) < Self.maxGap ? " " + text : text
    }
}

/// Editing the personal word list.
extension Vocabulary {
    public static func terms(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// Adds a term unless it is already there, ignoring case.
    public static func adding(_ term: String, to terms: [String]) -> [String] {
        let term = term.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let isKnown = terms.contains { $0.caseInsensitiveCompare(term) == .orderedSame }
        return term.isEmpty || term.hasPrefix("#") || isKnown ? terms : terms + [term]
    }
}
