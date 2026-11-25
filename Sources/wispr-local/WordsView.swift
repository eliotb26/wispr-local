import SwiftUI
import WisprLocalCore

struct WordsView: View {
    @State private var terms: [String] = []
    @State private var draft = ""
    @State private var problem: String?

    var body: some View {
        Page(title: "Words", subtitle: "Names and terms to spell correctly.") {
            HStack(spacing: 8) {
                GraphiteField(prompt: "Add a name or term", text: $draft).onSubmit(add)
                Button("Add", action: add).graphite(.primary).disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 16)
            if let problem { Text(problem).foregroundStyle(Theme.danger).padding(.bottom, 12) }
            ForEach(terms, id: \.self) { term in
                GraphiteRow(title: term) {
                    Button("Remove") { save(terms.filter { $0 != term }) }.graphite(.ghost, small: true)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Paths.vocabulary.path) else { return }
        do {
            terms = Vocabulary.terms(in: try String(contentsOf: Paths.vocabulary, encoding: .utf8))
        } catch {
            problem = "Couldn't read your words: \(error.localizedDescription)"
        }
    }

    private func add() {
        save(Vocabulary.adding(draft, to: terms))
        draft = ""
    }

    private func save(_ new: [String]) {
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
