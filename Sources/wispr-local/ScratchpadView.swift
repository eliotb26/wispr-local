import SwiftUI
import WisprLocalCore

struct ScratchpadView: View {
    @ObservedObject var store: NoteStore
    @State private var selected: UUID?
    @State private var deleting: Note?
    @FocusState private var isWriting: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Scratchpad").font(Theme.title).tracking(-0.3).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: add) { Image(systemName: "square.and.pencil") }.graphite(.ghost, small: true).help("New note").accessibilityLabel("New note")
                }
                .padding(.bottom, 12)
                ScrollView { VStack(spacing: 2) { ForEach(store.items, content: row) } }
                if let problem = store.problem { Text(problem).font(Theme.small).foregroundStyle(Theme.danger) }
            }
            .padding(.horizontal, 12).padding(.top, 44).frame(width: 216)
            Rectangle().fill(Theme.border).frame(width: 1)
            editor
        }
        .confirmationDialog("Delete this note?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { note in
            Button("Delete", role: .destructive) { delete(note) }
        }
        .onAppear { selected = selected ?? store.items.first?.id }
    }

    @ViewBuilder private var editor: some View {
        if let note = store.items.first(where: { $0.id == selected }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.date.formatted(date: .abbreviated, time: .shortened)).font(Theme.small).foregroundStyle(Theme.muted)
                    Spacer()
                    Button("Delete") { if note.text.isEmpty { delete(note) } else { deleting = note } }.graphite(.ghost, small: true)
                }
                .padding(.trailing, 40)
                TextEditor(text: Binding(get: { note.text }, set: { edit(note.id, $0) }))
                    .font(Theme.reading).lineSpacing(5).scrollContentBackground(.hidden).focused($isWriting).padding(.leading, -5)
                    .accessibilityLabel("Note")
            }
            .padding(.horizontal, 32).padding(.top, 16).padding(.bottom, 24)
        } else {
            VStack(spacing: 12) {
                Text("A place to think out loud").font(Theme.title).tracking(-0.3)
                Button("New note", action: add).graphite(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func row(_ note: Note) -> some View {
        Button { selected = note.id } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title).font(Theme.bodyMedium).lineLimit(1)
                Text(note.date.formatted(.dateTime.month().day())).font(Theme.caption).foregroundStyle(Theme.muted)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(note.id == selected ? Theme.hover : .clear)).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(note.id == selected ? .isSelected : [])
    }

    private func add() {
        let blank = store.items.first { $0.text.isEmpty }
        let note = blank ?? Note()
        if blank == nil { store.save([note] + store.items) }
        selected = note.id
        DispatchQueue.main.async { isWriting = true }
    }

    private func edit(_ id: UUID, _ text: String) {
        guard let note = store.items.first(where: { $0.id == id }), note.text != text else { return }
        store.save(store.items.map { $0.id == id ? note.editing(text) : $0 })
    }

    private func delete(_ note: Note) {
        store.save(store.items.filter { $0.id != note.id })
        selected = store.items.first?.id
    }
}
