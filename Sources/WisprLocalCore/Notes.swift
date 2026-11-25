import Foundation

/// A scratchpad note.
public struct Note: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let text: String

    public init(id: UUID = UUID(), date: Date = Date(), text: String = "") {
        self.id = id
        self.date = date
        self.text = text
    }

    public func editing(_ text: String, at date: Date = Date()) -> Note { Note(id: id, date: date, text: text) }

    public var title: String {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? "New note"
    }
}

/// A list saved as one JSON file only this user can read.
public struct JSONFile<Value: Codable>: @unchecked Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    /// Nil when nothing has been saved yet.
    public func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Private before it holds anything, then swapped in.
        let part = url.appendingPathExtension("part")
        try? FileManager.default.removeItem(at: part)
        guard FileManager.default.createFile(atPath: part.path, contents: try JSONEncoder().encode(value), attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
        guard rename(part.path, url.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
