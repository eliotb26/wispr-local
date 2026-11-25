import Foundation
import Testing
@testable import WisprLocalCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func entry(_ text: String, age: TimeInterval = 0, seconds: Double = 60, outcome: Dictation.Outcome = .typed, ms: Int = 1000) -> Dictation {
    Dictation(date: now.addingTimeInterval(-age), seconds: seconds, app: "Notes", outcome: outcome, text: text, heard: text, totalMs: ms)
}

@Suite("History")
struct HistoryTests {
    private let file = HistoryFile(url: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jsonl"))

    @Test("saves privately and reads back, skipping a damaged line")
    func roundTrip() throws {
        defer { try? FileManager.default.removeItem(at: file.url) }
        #expect(try file.load().isEmpty)
        let first = entry("line one\nline two \u{1F642}"), second = entry("two")
        try file.append(first)
        let handle = try FileHandle(forWritingTo: file.url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{cut short".utf8))
        try handle.close()
        try file.append(second)
        #expect(try file.load() == [first, second])
        let mode = try FileManager.default.attributesOfItem(atPath: file.url.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    @Test("retention drops old entries", arguments: [(Retention.off, 0), (.day, 1), (.month, 2), (.forever, 3)])
    func retention(rule: Retention, kept: Int) {
        let entries = [entry("a", age: 40 * 86_400), entry("b", age: 2 * 86_400), entry("c", age: 60)]
        #expect(rule.keep(entries, now: now).count == kept)
    }

    @Test("stats count typed words only")
    func stats() {
        let stats = DictationStats([entry("one two three", ms: 900), entry("four five", ms: 1200), entry("", outcome: .silent), entry("", outcome: .failed)])
        #expect(stats.words == 5)
        #expect(stats.wordsPerMinute == 3)
        #expect(stats.medianMs == 1200)
        #expect(DictationStats([]).wordsPerMinute == 0)
    }

    @Test("a correction replaces the text; an unchanged or blank one clears it")
    func correction() {
        let fixed = entry("ask Jotty").correcting(to: " ask Jottey ")
        #expect(fixed.finalText == "ask Jottey")
        #expect(fixed.text == "ask Jotty")
        #expect(fixed.correcting(to: "ask Jotty").corrected == nil)
        #expect(fixed.correcting(to: " ").corrected == nil)
    }

    @Test("search covers text and app")
    func search() {
        #expect(entry("Hello there").matches("hello"))
        #expect(entry("Hello").matches("notes"))
        #expect(!entry("Hello").matches("mail"))
    }
}

@Suite("Joiner")
struct JoinerTests {
    @Test("adds a space only when nothing happened in between")
    func joining() {
        var joiner = Joiner()
        #expect(joiner.join("One.", app: "Notes", at: now) == "One.")
        #expect(joiner.join("Two.", app: "Notes", at: now + 5) == " Two.")
        #expect(joiner.join("Three.", app: "Mail", at: now + 6) == "Three.")
        joiner.userActed()
        #expect(joiner.join("Four.", app: "Mail", at: now + 7) == "Four.")
        #expect(joiner.join("Five.", app: "Mail", at: now + 500) == "Five.")
    }
}

@Suite("Vocabulary list")
struct VocabularyListTests {
    @Test("adds a term once and ignores comments")
    func adding() {
        #expect(Vocabulary.terms(in: "# note\nJottey\n\n Atrios ") == ["Jottey", "Atrios"])
        #expect(Vocabulary.adding(" Stay\nAcademic ", to: ["Jottey"]) == ["Jottey", "Stay Academic"])
        #expect(Vocabulary.adding("jottey", to: ["Jottey"]) == ["Jottey"])
        #expect(Vocabulary.adding("#x", to: []) == [])
    }
}
