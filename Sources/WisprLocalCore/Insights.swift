import Foundation

/// What the history says about how someone dictates.
public struct Insights: Equatable, Sendable {
    public struct Day: Equatable, Identifiable, Sendable {
        public let date: Date
        public let words: Int
        public var id: Date { date }
    }

    public struct App: Equatable, Identifiable, Sendable {
        public let name: String
        public let words: Int
        public var id: String { name }
    }

    /// A common typing speed, for the time-saved estimate.
    public static let typingWordsPerMinute = 40.0

    public let days: [Day] // oldest first, ending today
    public let apps: [App] // most words first
    public let streak: Int
    public let minutesSaved: Int
    public let corrected: Int

    public init(_ entries: [Dictation], now: Date, dayCount: Int = 14, calendar: Calendar = .current) {
        let typed = entries.filter { $0.outcome == .typed }
        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(grouping: typed) { calendar.startOfDay(for: $0.date) }.mapValues(Self.words)
        func day(_ back: Int) -> Date { calendar.date(byAdding: .day, value: -back, to: today) ?? today }

        days = (0..<dayCount).reversed().map { Day(date: day($0), words: byDay[day($0)] ?? 0) }
        apps = Dictionary(grouping: typed, by: \.app).map { App(name: $0.key, words: Self.words($0.value)) }
            .sorted { ($0.words, $1.name) > ($1.words, $0.name) }
        // Today doesn't break a streak until it's over.
        let firstDay = byDay[today] == nil ? 1 : 0
        streak = (firstDay...).prefix { byDay[day($0)] != nil }.count
        let spoken = typed.reduce(0) { $0 + $1.seconds + Double($1.totalMs) / 1000 } / 60
        minutesSaved = max(0, Int((Double(Self.words(typed)) / Self.typingWordsPerMinute - spoken).rounded()))
        corrected = typed.filter { $0.corrected != nil }.count
    }

    private static func words(_ entries: [Dictation]) -> Int {
        entries.reduce(0) { $0 + Cleanup.wordCount($1.finalText) }
    }
}
