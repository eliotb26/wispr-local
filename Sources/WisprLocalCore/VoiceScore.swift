import Foundation

/// Compares what was read aloud with what was heard.
public enum VoiceScore {
    private static let numbers = ["three": "3", "thirty": "30", "twenty": "20", "330": "3 30"]
    static let shortestCandidate = 4

    /// Words wrong, missing or added.
    public static func errors(expected: String, heard: String) -> Int {
        let want = tokens(expected), got = tokens(heard)
        return want.enumerated().reduce(Array(0...got.count)) { row, item in
            got.indices.reduce([item.offset + 1]) { next, j in
                next + [min(row[j + 1] + 1, next[j] + 1, row[j] + (item.element == got[j] ? 0 : 1))]
            }
        }.last ?? 0
    }

    public static func wordCount(_ text: String) -> Int { tokens(text).count }

    /// Terms that might teach the model a missed word: the word by itself, then with the one after it.
    public static func candidates(expected: String, heard: String) -> [String] {
        let want = tokens(expected), got = Set(tokens(heard))
        return want.indices.filter { want[$0].count >= shortestCandidate && !got.contains(want[$0]) }.flatMap { index in
            [want[index]] + (index + 1 < want.count ? ["\(want[index]) \(want[index + 1])"] : [])
        }
    }

    private static func tokens(_ text: String) -> [String] {
        text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "%", with: " percent")
            .split { !($0.isLetter || $0.isNumber || $0 == "'") }
            .flatMap { (numbers[String($0)] ?? String($0)).split(separator: " ").map(String.init) }
    }
}
