import SwiftUI
import WisprLocalCore

struct WordsView: View {
    @ObservedObject var words: WordStore
    @State private var draft = ""

    var body: some View {
        Page(title: "Words", subtitle: "Names and terms to spell correctly.") {
            HStack(spacing: 8) {
                GraphiteField(prompt: "Add a name or term", text: $draft).onSubmit(add)
                Button("Add", action: add).graphite(.primary).disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 16)
            if let problem = words.problem { Text(problem).foregroundStyle(Theme.danger).padding(.bottom, 12) }
            if !words.terms.isEmpty { Card { ForEach(words.terms, id: \.self) { term in
                GraphiteRow(title: term, isLast: term == words.terms.last) {
                    Button("Remove") { words.save(words.terms.filter { $0 != term }) }.graphite(.ghost, small: true)
                }
            } } }
        }
        .onAppear(perform: words.load)
    }

    private func add() {
        words.save(Vocabulary.adding(draft, to: words.terms))
        draft = ""
    }
}
