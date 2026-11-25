import Foundation

/// Checks that a cleaned dictation only removed disfluencies: no added, lost or reordered words.
public enum CleanupGuard {
    private static let fillers: Set<String> = ["um", "umm", "uh", "uhh", "er", "erm", "hmm"]
    /// Doubles of these can be meant ("had had", "very very"), so removing one counts as a change.
    private static let meaningfulDoubles: Set<String> = ["had", "that", "very", "really", "no"]
    private static let correctionCues = ["no wait", "wait no", "actually no", "i mean", "scratch that", "sorry i meant", "or rather", "make that", "correction"]

    public static func hasCorrection(_ text: String) -> Bool {
        let normalized = " " + words(text).joined(separator: " ") + " "
        return correctionCues.contains { normalized.contains(" \($0) ") }
    }

    /// True when `cleaned` is the raw words in order, and every skipped word was a filler,
    /// a stutter fragment or part of a phrase that is immediately repeated.
    public static func isFaithful(_ cleaned: String, to raw: String) -> Bool {
        collapse(words(Disfluency.dropAsideLike(raw))) == collapse(words(Disfluency.dropAsideLike(cleaned))) && !words(cleaned).isEmpty
    }

    private static let shortestRespelling = 4
    private static let maxRespelling = 2
    private static let lengthRange = 0.3...1.2

    /// A looser check for Claude's edits, which may drop corrected words but not bring in new ones. A new word must be
    /// a number or a respelling of a spoken one, such as "Jottey" for "Jotty".
    public static func isPlausible(_ edited: String, for raw: String) -> Bool {
        let output = words(edited), spoken = words(raw)
        guard !output.isEmpty, !spoken.isEmpty else { return false }
        let known = Set(spoken)
        return output.allSatisfy { known.contains($0) || isNumber($0) || isRespelling($0, of: spoken) }
            && lengthRange.contains(Double(output.count) / Double(spoken.count))
    }

    private static func isNumber(_ word: String) -> Bool { word.contains(where: \.isNumber) }

    private static func isRespelling(_ word: String, of spoken: [String]) -> Bool {
        word.count >= shortestRespelling && spoken.contains {
            $0.first == word.first && $0.count >= shortestRespelling && editDistance(Array($0), Array(word)) <= maxRespelling
        }
    }

    private static func editDistance(_ from: [Character], _ to: [Character]) -> Int {
        from.enumerated().reduce(Array(0...to.count)) { row, item in
            to.indices.reduce([item.offset + 1]) { next, j in
                next + [min(row[j + 1] + 1, next[j] + 1, row[j] + (item.element == to[j] ? 0 : 1))]
            }
        }.last ?? 0
    }

    static let longestRepeat = 4

    /// Drops fillers, stutter fragments ("b b budget") and immediate repeats ("we should we should").
    static func collapse(_ input: [String]) -> [String] {
        let spoken = input.filter { !fillers.contains($0) }
        var result: [String] = []
        for (index, word) in spoken.enumerated() {
            if isFragment(word, followedBy: spoken[(index + 1)...]) { continue }
            result.append(word)
            for length in 1...longestRepeat where result.count >= 2 * length {
                if length == 1 && meaningfulDoubles.contains(word) { continue }
                if Array(result.suffix(length)) == Array(result.dropLast(length).suffix(length)) {
                    result.removeLast(length)
                    break
                }
            }
        }
        return result
    }

    private static func isFragment(_ word: String, followedBy rest: ArraySlice<String>) -> Bool {
        guard word.count == 1, word != "a", word != "i", !word.first!.isNumber,
              let next = rest.first(where: { $0 != word }) else { return false }
        return next.hasPrefix(word)
    }

    static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split { !($0.isLetter || $0.isNumber || $0 == "'") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { !$0.isEmpty }
    }
}
