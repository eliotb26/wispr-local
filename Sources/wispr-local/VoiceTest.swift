import SwiftUI
import WisprLocalCore

/// Saves sentences read aloud, then tries words that make the speech model hear them better.
/// Recordings sit next to their text, as scripts/voice-eval.py expects.
final class VoiceTest: ObservableObject {
    static let sentences = [
        "Can you send me the latest draft before lunch?", "I think we should ship the fix on Thursday.",
        "Let's move the meeting to three thirty on Friday.", "The numbers in the pricing page look wrong.",
        "Thanks for the quick reply, I really appreciate it.", "Please review my pull request when you get a chance.",
        "The build failed because the test database was empty.", "Add a filter so people can search by company.",
        "What would it take to make this work offline?", "I'll follow up with Sarah and Brian tomorrow morning.",
        "We need a stronger opening line for the newsletter.", "Rewrite this paragraph so it sounds more like me.",
        "The customer asked about security and data storage.", "Schedule a call with the product team next week.",
        "Show me every account that hasn't replied in thirty days.", "Split this function into smaller pieces and add tests.",
        "Our revenue grew twenty percent compared with last year.", "Could you explain why the first version was slower?",
        "Remember to update the design system before we launch.", "Three things matter most: speed, quality and trust.",
        "I'd rather start small and improve it every week.", "Please book a train to Boston for Wednesday evening.",
        "The research paper compares several robot learning methods.", "Make the button bigger and move it to the right.",
        "She said the proposal was clear but a little too long.", "Does the application still work without an internet connection?",
        "Create a spreadsheet with names, titles and email addresses.", "My biggest question is whether people will pay for this.",
        "Stop the server, clear the cache and try again.", "Great work, let's talk about the next step on Monday.",
    ]

    @Published var index = 0
    @Published var status = ""
    @Published private(set) var isTuning = false
    @Published private(set) var result: TuneResult?
    /// A recording and the terms to expect, to text. Called off the main thread.
    var transcribe: (Data, [String]) throws -> String = { _, _ in throw AppError.process("not ready") }
    static let minRecordings = 5
    private static let maxCandidates = 12
    var isDone: Bool { index >= Self.sentences.count }

    func open() {
        do {
            try FileManager.default.createDirectory(at: Paths.voiceTest, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: Paths.voiceTest.path)
        } catch {
            status = "Couldn't make the folder: \(error.localizedDescription)"
        }
        index = Self.sentences.indices.first { !FileManager.default.fileExists(atPath: file($0, "wav").path) } ?? Self.sentences.count
    }

    func save(_ samples: [Float]) {
        guard index < Self.sentences.count else { return }
        do {
            try WavEncoder.encode(samples).write(to: file(index, "wav"))
            try Data(Self.sentences[index].utf8).write(to: file(index, "txt"))
            status = ""
            index += 1
        } catch {
            status = "Couldn't save: \(error.localizedDescription)"
        }
    }

    func back() { if index > 0 { index -= 1 } }

    private func file(_ index: Int, _ ext: String) -> URL {
        Paths.voiceTest.appendingPathComponent(String(format: "%02d.%@", index + 1, ext))
    }

    /// Keeps a term only if every recording, taken together, then has fewer wrong words.
    func tune(_ words: WordStore) {
        guard !isTuning, words.problem == nil else { return }
        isTuning = true
        result = nil
        status = ""
        let terms = words.terms, count = index
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = Result { try self.search(from: terms, count: count) }
            DispatchQueue.main.async {
                self.isTuning = false
                switch outcome {
                case .success(let found):
                    words.save(found.added.reduce(words.terms) { Vocabulary.adding($1, to: $0) })
                    if words.problem == nil { self.result = found } else { self.status = words.problem ?? "" }
                case .failure(let error):
                    log("tuning failed: \(type(of: error))")
                    self.status = "Couldn't check your recordings."
                }
            }
        }
    }

    private struct Sample {
        let wav: Data
        let text: String
    }

    private func search(from start: [String], count: Int) throws -> TuneResult {
        let samples = try (0..<count).filter { FileManager.default.fileExists(atPath: file($0, "wav").path) }
            .map { Sample(wav: try Data(contentsOf: file($0, "wav")), text: Self.sentences[$0]) }
        func errors(_ sample: Sample, _ terms: [String]) throws -> Int { VoiceScore.errors(expected: sample.text, heard: try transcribe(sample.wav, terms)) }

        let heard = try samples.map { ($0, try transcribe($0.wav, start)) }
        let before = heard.reduce(0) { $0 + VoiceScore.errors(expected: $1.0.text, heard: $1.1) }
        var best = before, kept: [String] = []
        let candidates = heard.flatMap { sample, text in VoiceScore.candidates(expected: sample.text, heard: text).map { (sample, $0) } }
        for (sample, term) in candidates.prefix(Self.maxCandidates) {
            let terms = Vocabulary.adding(term, to: start + kept)
            // The quick check first: does it help the sentence it came from?
            guard terms.count > start.count + kept.count, try errors(sample, terms) < errors(sample, start + kept) else { continue }
            let total = try samples.reduce(0) { $0 + (try errors($1, terms)) }
            if total < best { (best, kept) = (total, kept + [term]) }
        }
        return TuneResult(words: samples.reduce(0) { $0 + VoiceScore.wordCount($1.text) }, before: before, after: best, added: kept)
    }
}

struct TuneResult: Equatable {
    let words: Int
    let before: Int
    let after: Int
    let added: [String]

    var summary: String {
        if before == 0 { return "It heard all \(words) words right. Nothing to fix." }
        if added.isEmpty { return "\(before) of \(words) words were wrong, and no added word fixed them. Nothing was changed." }
        return "Wrong words went from \(before) to \(after) of \(words). Added \(added.joined(separator: ", ")) to Words."
    }
}

struct VoicePane: View {
    @ObservedObject var test: VoiceTest
    @ObservedObject var voice: LiveVoice
    @ObservedObject var words: WordStore
    let keyLabel: String

    var body: some View {
        Pane(title: "Tune to your voice", subtitle: "Read at least \(VoiceTest.minRecordings) sentences, then Tune tries words that fix what it misheard.") {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(test.index), total: Double(VoiceTest.sentences.count)).tint(Theme.control)
                    Text("\(test.index) of \(VoiceTest.sentences.count) recorded").font(Theme.small).foregroundStyle(Theme.muted).monospacedDigit()
                }
                Text(test.isDone ? "All recorded" : VoiceTest.sentences[test.index]).font(Theme.page).tracking(-0.5)
                    .fixedSize(horizontal: false, vertical: true).frame(minHeight: 64, alignment: .topLeading)
                VoiceField(voice: voice).frame(height: 80).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(hint).font(Theme.small).foregroundStyle(test.status.isEmpty ? Theme.muted : Theme.danger).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(test.isTuning ? "Tuning\u{2026}" : "Tune") { test.tune(words) }.graphite(.primary).disabled(test.isTuning || test.index < VoiceTest.minRecordings)
                    Button("Redo previous") { test.back() }.graphite().disabled(test.index == 0 || test.isTuning)
                    Button("Show recordings") { NSWorkspace.shared.open(Paths.voiceTest) }.graphite(.ghost)
                }
                if let result = test.result { Text(result.summary).font(Theme.bodyMedium).fixedSize(horizontal: false, vertical: true) }
            }
        }
        .onAppear(perform: test.open)
    }

    private var hint: String {
        if !test.status.isEmpty { return test.status }
        return test.isDone ? "Recordings stay on this Mac." : "Hold \(keyLabel), read it the way you normally talk, then let go."
    }
}
