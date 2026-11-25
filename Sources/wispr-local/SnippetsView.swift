import SwiftUI
import WisprLocalCore

struct SnippetsView: View {
    @ObservedObject var store: SnippetStore
    @State private var phrase = ""
    @State private var text = ""
    @State private var editing: Snippet?

    var body: some View {
        Page(title: "Snippets", subtitle: "Say a short phrase and it types the long version.") {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    GraphiteField(prompt: "When I say, e.g. my meeting link", text: $phrase)
                    TextEditor(text: $text).font(Theme.body).scrollContentBackground(.hidden).padding(8).frame(height: 84)
                        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.borderStrong))
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty { Text("Type this").foregroundStyle(Theme.placeholder).padding(.horizontal, 13).padding(.vertical, 8).allowsHitTesting(false) }
                        }
                        .accessibilityLabel("Type this")
                    HStack {
                        Spacer()
                        if editing != nil { Button("Cancel", action: clear).graphite(.ghost) }
                        Button(editing == nil ? "Add snippet" : "Save", action: add).graphite(.primary).disabled(!Snippet(phrase: phrase, text: text).isValid)
                    }
                }
                .padding(20)
            }
            if let problem = store.problem { Text(problem).foregroundStyle(Theme.danger).padding(.top, 12) }
            if !store.items.isEmpty {
                Card { ForEach(store.items) { snippet in
                    GraphiteRow(title: snippet.phrase, detail: snippet.text, isLast: snippet.id == store.items.last?.id) {
                        Button("Edit") { (editing, phrase, text) = (snippet, snippet.phrase, snippet.text) }.graphite(.ghost, small: true)
                        Button("Remove") { store.save(store.items.filter { $0.id != snippet.id }) }.graphite(.ghost, small: true)
                    }
                } }
                .padding(.top, 16)
            }
        }
    }

    private func add() {
        store.save(Snippets.adding(Snippet(id: editing?.id ?? UUID(), phrase: phrase, text: text), to: store.items))
        if store.problem == nil { clear() }
    }

    private func clear() { (editing, phrase, text) = (nil, "", "") }
}
