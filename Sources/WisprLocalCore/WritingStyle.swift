import Foundation

/// How finished text is punctuated and capitalised. It never changes the words.
public enum WritingStyle: String, CaseIterable, Sendable {
    case polished, relaxed, lowercase

    public func apply(to text: String) -> String {
        switch self {
        case .polished: return text
        case .relaxed: return Self.withoutLastPeriod(text)
        case .lowercase: return Self.withoutLastPeriod(text).lowercased()
        }
    }

    private static func withoutLastPeriod(_ text: String) -> String {
        text.hasSuffix(".") && !text.hasSuffix("..") ? String(text.dropLast()) : text
    }
}

/// Kinds of apps that can each have their own style.
public enum AppGroup: String, CaseIterable, Sendable {
    case messages, work, email, other

    private static let groups: [AppGroup: Set<String>] = [
        .messages: ["messages", "whatsapp", "\u{200E}whatsapp", "telegram", "signal", "messenger", "discord"],
        .work: ["slack", "microsoft teams", "microsoft teams classic", "zoom", "zoom.us", "roam", "google chat"],
        .email: ["mail", "microsoft outlook", "outlook", "superhuman", "spark", "spark desktop", "mimestream"],
    ]

    public init(app: String) {
        self = Self.groups.first { $0.value.contains(app.lowercased()) }?.key ?? .other
    }
}
