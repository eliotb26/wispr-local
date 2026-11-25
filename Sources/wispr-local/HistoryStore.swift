import Foundation
import WisprLocalCore

/// The history shown in the window. Use from the main thread.
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [Dictation] = [] // newest first
    @Published var problem: String?
    @Published private(set) var totals = Totals()
    @Published var newRank: Rank? // shown once, then cleared
    private let totalsFile = JSONFile<Totals>(url: Paths.totals)
    private let file = HistoryFile(url: Paths.history)
    private var purgeTimer: Timer?

    private var areTotalsLoaded = false
    private var isLoaded = false // a file that couldn't be read must never be overwritten

    init() {
        attempt {
            try FileManager.default.createDirectory(at: Paths.support, withIntermediateDirectories: true)
            entries = try file.load().reversed()
            isLoaded = true
        }
        attempt {
            let saved = try totalsFile.load()
            guard saved != nil || isLoaded else { return } // never start from a history that couldn't be read
            let counted = Totals(entries)
            totals = saved.map { $0.months.isEmpty ? $0.with(months: counted.months) : $0 } ?? counted
            areTotalsLoaded = true
        }
        purge()
        purgeTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in self?.purge() }
    }

    func add(_ entry: Dictation, samples: [Float]) {
        guard Settings.retention != .off else { return }
        attempt {
            try file.append(entry)
            entries = [entry] + entries
            try count(entry)
            guard Settings.keepAudio, entry.outcome == .typed else { return }
            try FileManager.default.createDirectory(at: Paths.recordings, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try WavEncoder.encode(samples).write(to: audio(entry.id))
        }
    }

    private func count(_ entry: Dictation) throws {
        guard areTotalsLoaded else { return }
        let updated = totals.adding(entry)
        try totalsFile.save(updated)
        let before = Rank(words: totals.words), after = Rank(words: updated.words)
        totals = updated
        if after != before { newRank = after }
    }

    func countClaudeEdit() {
        guard areTotalsLoaded, Settings.retention != .off else { return }
        attempt {
            let updated = totals.addingClaudeEdit(at: Date())
            try totalsFile.save(updated)
            totals = updated
        }
    }

    func correct(_ entry: Dictation, to text: String) {
        replace(with: entries.map { $0.id == entry.id ? $0.correcting(to: text) : $0 })
    }

    func delete(_ entry: Dictation) { replace(with: entries.filter { $0.id != entry.id }) }

    /// Deletes the history, its recordings and the timing log.
    func deleteAll() {
        attempt {
            for url in [file.url, Paths.recordings, Paths.runs, Paths.totals] where FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            entries = []
            totals = Totals()
            isLoaded = true
            areTotalsLoaded = true
        }
    }

    /// Removes what the retention setting no longer allows. Runs on launch, hourly and when the setting changes.
    func purge() {
        let kept = Settings.retention.keep(entries, now: Date())
        if kept.count != entries.count { replace(with: kept) }
    }

    private func replace(with kept: [Dictation]) {
        attempt {
            guard isLoaded else { throw AppError.process("the history file could not be read") }
            try file.save(kept.reversed())
            let keptIDs = Set(kept.map(\.id))
            let gone = entries.filter { !keptIDs.contains($0.id) }
            entries = kept
            let failures = gone.map { audio($0.id) }.filter { FileManager.default.fileExists(atPath: $0.path) }
                .compactMap { url in Result { try FileManager.default.removeItem(at: url) }.failure }
            if let first = failures.first { throw first }
        }
    }

    private func audio(_ id: UUID) -> URL { Paths.recordings.appendingPathComponent("\(id.uuidString).wav") }

    private func attempt(_ work: () throws -> Void) {
        do {
            try work()
            if isLoaded { problem = nil }
        } catch {
            log("history: \(error)")
            problem = "History couldn't be saved: \(error.localizedDescription)"
        }
    }
}

private extension Result {
    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
