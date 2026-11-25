import XCTest
@testable import WisprLocalCore

final class FeatureTests: XCTestCase {
    private let calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    private let now = Date(timeIntervalSince1970: 1_764_072_000) // 2025-11-25 12:00 UTC, a Tuesday

    private func entry(_ back: Double, _ heard: String = "one two three", outcome: Dictation.Outcome = .typed) -> Dictation {
        Dictation(date: now.addingTimeInterval(-back * 86_400), seconds: 60, app: "Notes", outcome: outcome, text: heard, heard: heard)
    }

    func testTotalsCountTypedSpeechAndSurviveSaving() throws {
        let totals = Totals([entry(0), entry(1), entry(2, outcome: .silent)], calendar: calendar)
        XCTAssertEqual(totals.words, 6)
        XCTAssertEqual(totals.wordsPerMinute, 3)
        XCTAssertEqual(Totals().wordsPerMinute, 0)
        let file = JSONFile<Totals>(url: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID())/totals.json"))
        XCTAssertNil(try file.load())
        try file.save(totals)
        XCTAssertEqual(try file.load(), totals)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.url.path)[.posixPermissions] as? Int, 0o600)
    }

    func testStreakKeepsYesterdayUntilTodayEnds() {
        XCTAssertEqual(Totals([entry(1), entry(2), entry(4)], calendar: calendar).streak(now: now, calendar: calendar), 2)
        XCTAssertEqual(Totals([entry(0), entry(1)], calendar: calendar).streak(now: now, calendar: calendar), 2)
        XCTAssertEqual(Totals([entry(2)], calendar: calendar).streak(now: now, calendar: calendar), 0)
    }

    func testWeekMarksActiveDays() {
        let week = Totals([entry(0)], calendar: calendar).week(now: now, calendar: calendar)
        XCTAssertEqual(week.map(\.isActive), [false, false, true, false, false, false, false])
    }

    func testMonthsAndOldFiles() throws {
        let totals = Totals([entry(0), entry(30)], calendar: calendar).addingClaudeEdit(at: now, calendar: calendar)
        XCTAssertEqual(totals.month(now, calendar: calendar), Totals.Month(words: 3, claudeEdits: 1))
        XCTAssertEqual(totals.months.count, 2)
        let old = try JSONDecoder().decode(Totals.self, from: Data(#"{"words":5,"seconds":2,"days":["2025-11-25"]}"#.utf8))
        XCTAssertEqual(old.words, 5)
        XCTAssertEqual(old.with(months: totals.months).month(now, calendar: calendar).words, 3)
    }

    func testRanks() {
        XCTAssertEqual(Rank(words: 0), .hatchling)
        XCTAssertEqual(Rank(words: 2_500), .songbird)
        XCTAssertEqual(Rank.hatchling.progress(at: 250), 0.5)
        XCTAssertNil(Rank.lyrebird.next)
        XCTAssertEqual(Rank.lyrebird.progress(at: 90_000), 1)
    }

    func testSnippetAloneOrInsideASentence() {
        let snippets = [Snippet(phrase: "my  link", text: "https://example.com/$1"), Snippet(phrase: "my link two", text: "my link")]
        XCTAssertEqual(Snippets.expand("My link.", with: snippets), "https://example.com/$1")
        XCTAssertEqual(Snippets.expand("Here's my link, thanks.", with: snippets), "Here's https://example.com/$1, thanks.")
        XCTAssertEqual(Snippets.expand("Use my link two now", with: snippets), "Use my link now")
        XCTAssertEqual(Snippets.expand("my linked list", with: snippets), "my linked list")
        XCTAssertEqual(Snippets.expand("hello", with: []), "hello")
    }

    func testAddingSnippetReplacesSamePhraseAndRejectsBlank() {
        let old = Snippet(phrase: "sig", text: "a"), new = Snippet(phrase: "SIG", text: "b")
        XCTAssertEqual(Snippets.adding(new, to: [old]), [new])
        XCTAssertEqual(Snippets.adding(Snippet(phrase: " ", text: "x"), to: [old]), [old])
    }

    func testStylesNeverChangeWords() {
        XCTAssertEqual(WritingStyle.polished.apply(to: "Hi Sam."), "Hi Sam.")
        XCTAssertEqual(WritingStyle.relaxed.apply(to: "Hi Sam. See you."), "Hi Sam. See you")
        XCTAssertEqual(WritingStyle.relaxed.apply(to: "Well..."), "Well...")
        XCTAssertEqual(WritingStyle.lowercase.apply(to: "Hi Sam?"), "hi sam?")
        XCTAssertEqual(AppGroup(app: "Slack"), .work)
        XCTAssertEqual(AppGroup(app: "Mail"), .email)
        XCTAssertEqual(AppGroup(app: "Xcode"), .other)
    }

    func testVoiceScore() {
        XCTAssertEqual(VoiceScore.errors(expected: "The pricing page at three thirty.", heard: "the pressing page at 3:30"), 1)
        XCTAssertEqual(VoiceScore.errors(expected: "Grew twenty percent", heard: "grew 20%"), 0)
        XCTAssertEqual(VoiceScore.errors(expected: "one two", heard: ""), 2)
        XCTAssertEqual(VoiceScore.candidates(expected: "The pricing page is up.", heard: "The pressing page is up."), ["pricing", "pricing page"])
        XCTAssertEqual(VoiceScore.candidates(expected: "same words", heard: "same words"), [])
        XCTAssertEqual(VoiceScore.wordCount("one two three"), 3)
    }

    func testNotes() {
        XCTAssertEqual(Note(text: "\n  Plan \nmore").title, "Plan")
        XCTAssertEqual(Note().title, "New note")
        let note = Note()
        XCTAssertEqual(note.editing("x").id, note.id)
    }

    private func ask(_ json: String, fails: Bool = false) -> [String: Any]? {
        let connector = Connector(history: { if fails { throw ConnectorConfig.Unreadable() }; return [self.entry(0, "buy milk"), self.entry(1, "call home")] },
                                  notes: { [Note(text: "idea one"), Note()] })
        return connector.reply(to: Data(json.utf8)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    private func textOf(_ reply: [String: Any]?) -> String? {
        ((reply?["result"] as? [String: Any])?["content"] as? [[String: Any]])?.first?["text"] as? String
    }

    private func call(_ tool: String, _ arguments: String = "{}", fails: Bool = false) -> [String: Any]? {
        ask(#"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"\#(tool)","arguments":\#(arguments)}}"#, fails: fails)
    }

    func testConnectorProtocol() {
        func version(_ asked: String) -> String? {
            (ask(#"{"id":1,"method":"initialize","params":{"protocolVersion":"\#(asked)"}}"#)?["result"] as? [String: Any])?["protocolVersion"] as? String
        }
        XCTAssertEqual(version("2024-11-05"), "2024-11-05")
        XCTAssertEqual(version("1999"), "2025-06-18")
        XCTAssertNil(ask(#"{"method":"notifications/initialized"}"#))
        XCTAssertNotNil(ask(#"{"id":1,"method":"ping"}"#)?["result"])
        XCTAssertEqual(((ask(#"{"id":1,"method":"tools/list"}"#)?["result"] as? [String: Any])?["tools"] as? [Any])?.count, 2)
        XCTAssertNotNil(ask("nope")?["error"])
        XCTAssertNotNil(ask(#"{"id":1,"method":"other"}"#)?["error"])
    }

    func testConnectorSearch() {
        XCTAssertEqual(textOf(call("search_dictations", #"{"query":"milk"}"#))?.hasSuffix("Notes: buy milk"), true)
        XCTAssertEqual(textOf(call("search_dictations", #"{"limit":1}"#))?.contains("call home"), false)
        XCTAssertEqual(textOf(call("search_dictations", #"{"query":"zzz"}"#)), "No dictations found.")
        XCTAssertEqual(textOf(call("search_notes"))?.hasSuffix("idea one"), true)
        XCTAssertNotNil(call("nope")?["error"])
        XCTAssertEqual((call("search_dictations", fails: true)?["result"] as? [String: Any])?["isError"] as? Bool, true)
    }

    func testConfigKeepsOtherSettings() throws {
        let before = Data(#"{"theme":"x","mcpServers":{"other":{"command":"a"}}}"#.utf8)
        let after = try ConnectorConfig.connecting(before, command: "/Applications/X.app/x", arguments: ["--mcp"])
        XCTAssertTrue(ConnectorConfig.isConnected(after))
        XCTAssertTrue(String(decoding: after, as: UTF8.self).contains("\"theme\" : \"x\""))
        let removed = try ConnectorConfig.disconnecting(after)
        XCTAssertFalse(ConnectorConfig.isConnected(removed))
        XCTAssertTrue(String(decoding: removed, as: UTF8.self).contains("other"))
        XCTAssertTrue(ConnectorConfig.isConnected(try ConnectorConfig.connecting(nil, command: "x", arguments: [])))
        XCTAssertFalse(ConnectorConfig.isConnected(nil))
        XCTAssertThrowsError(try ConnectorConfig.connecting(Data("// hi".utf8), command: "x", arguments: []))
        XCTAssertThrowsError(try ConnectorConfig.connecting(Data(#"{"mcpServers":[]}"#.utf8), command: "x", arguments: []))
    }
}
