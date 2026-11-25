import Foundation
import WisprLocalCore

/// A list saved in one file. Use from the main thread, except `current`.
class ListStore<Item: Codable>: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published private(set) var problem: String?
    private let file: JSONFile<[Item]>
    private let lock = NSLock()
    private var copy: [Item] = []
    private var isLoaded = false // a file that couldn't be read must never be overwritten

    /// Safe to read from any thread.
    var current: [Item] { lock.withLock { copy } }

    init(url: URL) {
        file = JSONFile(url: url)
        do {
            set(try file.load() ?? [])
            isLoaded = true
        } catch {
            fail("read", error)
        }
    }

    func save(_ new: [Item]) {
        guard isLoaded else { return }
        set(new) // shown even if saving fails, so nothing just typed disappears
        do {
            try file.save(new)
            problem = nil
        } catch {
            fail("save", error)
        }
    }

    private func set(_ new: [Item]) {
        items = new
        lock.withLock { copy = new }
    }

    private func fail(_ verb: String, _ error: Error) {
        log("couldn't \(verb) \(file.url.lastPathComponent): \(type(of: error))") // never the contents
        problem = "Couldn't \(verb) these: \(error.localizedDescription)"
    }
}

final class SnippetStore: ListStore<Snippet> {
    init() { super.init(url: Paths.snippets) }
}

final class NoteStore: ListStore<Note> {
    init() { super.init(url: Paths.notes) }
}

/// Names and terms to spell correctly.
final class WordStore: ObservableObject {
    @Published private(set) var terms: [String] = []
    @Published private(set) var problem: String?
    private var isLoaded = false

    init() { load() }

    func load() {
        guard FileManager.default.fileExists(atPath: Paths.vocabulary.path) else { isLoaded = true; return }
        do {
            terms = Vocabulary.unique(in: try String(contentsOf: Paths.vocabulary, encoding: .utf8))
            isLoaded = true
            problem = nil
        } catch {
            problem = "Couldn't read your words: \(error.localizedDescription)"
        }
    }

    func save(_ new: [String]) {
        guard isLoaded else { return }
        do {
            try FileManager.default.createDirectory(at: Paths.support, withIntermediateDirectories: true)
            try Data((new.joined(separator: "\n") + "\n").utf8).write(to: Paths.vocabulary, options: .atomic)
            terms = new
            problem = nil
        } catch {
            problem = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
