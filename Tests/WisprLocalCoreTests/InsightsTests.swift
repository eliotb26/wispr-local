import Foundation
import Testing
@testable import WisprLocalCore

@Suite("Insights")
struct InsightsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 15))! }

    private func entry(daysAgo: Int, words: Int, app: String = "Notes", seconds: Double = 6, outcome: Dictation.Outcome = .typed) -> Dictation {
        let text = Array(repeating: "word", count: words).joined(separator: " ")
        return Dictation(date: calendar.date(byAdding: .day, value: -daysAgo, to: now)!, seconds: seconds, app: app, outcome: outcome, text: text, heard: text)
    }

    private func insights(_ entries: [Dictation]) -> Insights { Insights(entries, now: now, calendar: calendar) }

    @Test("fills every day, oldest first, across the clock change")
    func days() {
        let result = Insights([entry(daysAgo: 0, words: 3), entry(daysAgo: 25, words: 4)], now: now, dayCount: 30, calendar: calendar)
        #expect(result.days.count == 30)
        #expect(result.days.last?.words == 3)
        #expect(result.days[4].words == 4)
    }

    @Test("a streak survives until today is over, and stops at a gap")
    func streak() {
        #expect(insights([entry(daysAgo: 0, words: 1), entry(daysAgo: 1, words: 1), entry(daysAgo: 3, words: 1)]).streak == 2)
        #expect(insights([entry(daysAgo: 1, words: 1), entry(daysAgo: 2, words: 1)]).streak == 2)
        #expect(insights([entry(daysAgo: 2, words: 1)]).streak == 0)
        #expect(insights([]).streak == 0)
    }

    @Test("ranks apps by words and ignores dictations that typed nothing")
    func apps() {
        let result = insights([entry(daysAgo: 0, words: 2, app: "Mail"), entry(daysAgo: 0, words: 5), entry(daysAgo: 0, words: 9, app: "X", outcome: .failed)])
        #expect(result.apps.map(\.name) == ["Notes", "Mail"])
    }

    @Test("time saved never goes below zero")
    func saved() {
        #expect(insights([entry(daysAgo: 0, words: 400, seconds: 180)]).minutesSaved == 7)
        #expect(insights([entry(daysAgo: 0, words: 1, seconds: 180)]).minutesSaved == 0)
    }
}
