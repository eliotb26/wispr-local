import Foundation

/// Removes the disfluencies that are safe to drop by rule: um/uh sounds and repeated phrases of 2 to 4 words.
/// Single repeated words stay, since "very very" and "had had" can be meant.
public enum Disfluency {
    /// "then, like, filters": only when set off by commas, so "I like pizza" is safe.
    static func dropAsideLike(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?i),\s+like,(?=\s)"#, with: "", options: .regularExpression)
    }

    public static func strip(_ text: String) -> String {
        let rules = [
            (#"(?i),?\s+(?:u+m+|u+h+|e+r+m+)\b,?(?=[.!?])"#, ""),        // "Bob, um." at the end of a sentence
            (#"(?i),\s+(?:u+m+|u+h+|e+r+m+)\b,?(?=\s)"#, ""),            // "that, um, sorts"
            (#"(?i)\b(?:u+m+|u+h+|e+r+m+)\b,?\s+"#, ""),                 // "Um, so" and "to uh Bob"
            (#"(?i)\b([\w']+(?:\s+[\w']+){1,3}),?\s+\1\b"#, "$1"),       // "we should, we should"
        ]
        let stripped = rules.reduce(dropAsideLike(text)) { $0.replacingOccurrences(of: $1.0, with: $1.1, options: .regularExpression) }
        return capitalizeSentences(stripped)
    }

    private static func capitalizeSentences(_ text: String) -> String {
        var result = ""
        var atStart = true
        for (index, character) in zip(text.indices, text) {
            result += atStart && character.isLetter ? character.uppercased() : String(character)
            if character.isLetter || character.isNumber { atStart = false }
            if ".!?".contains(character), text.index(after: index) < text.endIndex, text[text.index(after: index)] == " " {
                atStart = !text[..<index].hasSuffix(".m") // "4 p.m. and"
            }
        }
        return result
    }
}
