import Foundation

/// Lifetime counts. They outlive the history, so a short retention setting doesn't reset a streak.
/// Holds numbers and dates only, never what was said.
public struct Totals: Codable, Equatable, Sendable {
    public let words: Int
    public let seconds: TimeInterval
    public let days: Set<String> // "2026-11-25"

    public init(words: Int = 0, seconds: TimeInterval = 0, days: Set<String> = []) {
        self.words = words
        self.seconds = seconds
        self.days = days
    }

    public init(_ entries: [Dictation], calendar: Calendar = .current) {
        self = entries.reduce(Totals()) { $0.adding($1, calendar: calendar) }
    }

    /// Counts spoken words, so a long snippet isn't a shortcut to the next rank.
    public func adding(_ entry: Dictation, calendar: Calendar = .current) -> Totals {
        guard entry.outcome == .typed else { return self }
        return Totals(words: words + Cleanup.wordCount(entry.heard), seconds: seconds + entry.seconds,
                      days: days.union([Self.key(entry.date, calendar)]))
    }

    public var wordsPerMinute: Int { seconds > 0 ? Int((Double(words) / (seconds / 60)).rounded()) : 0 }

    public func isActive(_ date: Date, calendar: Calendar = .current) -> Bool { days.contains(Self.key(date, calendar)) }

    /// Days in a row up to now. Today doesn't break a streak until it's over.
    public func streak(now: Date, calendar: Calendar = .current) -> Int {
        let first = isActive(now, calendar: calendar) ? 0 : 1
        return (first...).prefix { back in
            calendar.date(byAdding: .day, value: -back, to: now).map { isActive($0, calendar: calendar) } ?? false
        }.count
    }

    /// The current week, oldest day first.
    public func week(now: Date, calendar: Calendar = .current) -> [(date: Date, isActive: Bool)] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .map { ($0, isActive($0, calendar: calendar)) }
    }

    private static func key(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// A rank earned by words spoken.
public enum Rank: String, CaseIterable, Sendable {
    case hatchling = "Hatchling", fledgling = "Fledgling", songbird = "Songbird", lark = "Lark", nightingale = "Nightingale", lyrebird = "Lyrebird"

    public var words: Int {
        switch self {
        case .hatchling: return 0
        case .fledgling: return 500
        case .songbird: return 2_500
        case .lark: return 10_000
        case .nightingale: return 25_000
        case .lyrebird: return 75_000
        }
    }

    public var next: Rank? { Self.allCases.first { $0.words > words } }

    public init(words: Int) { self = Self.allCases.last { $0.words <= words } ?? .hatchling }

    /// How far from this rank to the next, 0 to 1.
    public func progress(at words: Int) -> Double {
        guard let next else { return 1 }
        return min(1, max(0, Double(words - self.words) / Double(next.words - self.words)))
    }
}
