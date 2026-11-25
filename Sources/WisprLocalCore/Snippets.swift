import Foundation

/// A short phrase that types something longer.
public struct Snippet: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let phrase: String
    public let text: String

    public init(id: UUID = UUID(), phrase: String, text: String) {
        self.id = id
        self.phrase = phrase.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        self.text = text
    }

    public var isValid: Bool { !phrase.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

public enum Snippets {
    private static let edges = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

    /// Replaces each spoken phrase with its text. Longer phrases win, and typed text is never expanded again.
    public static func expand(_ spoken: String, with snippets: [Snippet]) -> String {
        let usable = snippets.filter(\.isValid).sorted { $0.phrase.count > $1.phrase.count }
        guard !usable.isEmpty else { return spoken }
        let whole = spoken.trimmingCharacters(in: edges)
        if let match = usable.first(where: { $0.phrase.trimmingCharacters(in: edges).caseInsensitiveCompare(whole) == .orderedSame }) { return match.text }
        let choices = usable.map { "(" + NSRegularExpression.escapedPattern(for: $0.phrase).replacingOccurrences(of: " ", with: "\\s+") + ")" }
        guard let pattern = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])(?:\(choices.joined(separator: "|")))(?![\\p{L}\\p{N}])", options: .caseInsensitive) else { return spoken }
        return pattern.matches(in: spoken, range: NSRange(spoken.startIndex..., in: spoken)).reversed().reduce(spoken) { result, match in
            guard let index = usable.indices.first(where: { match.range(at: $0 + 1).location != NSNotFound }),
                  let range = Range(match.range, in: result) else { return result }
            return result.replacingCharacters(in: range, with: usable[index].text)
        }
    }

    /// Adds a snippet, replacing any with the same phrase.
    public static func adding(_ snippet: Snippet, to snippets: [Snippet]) -> [Snippet] {
        guard snippet.isValid else { return snippets }
        return [snippet] + snippets.filter { $0.id != snippet.id && $0.phrase.caseInsensitiveCompare(snippet.phrase) != .orderedSame }
    }
}
