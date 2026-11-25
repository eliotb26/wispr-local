import SwiftUI
import WisprLocalCore

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    let keyLabel: String
    @State private var query = ""
    @State private var editing: Dictation?

    private var shown: [Dictation] { store.entries.filter { $0.matches(query) } }

    private var days: [(day: Date, entries: [Dictation])] {
        Dictionary(grouping: shown) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }.map { (day: $0.key, entries: $0.value) }
    }

    var body: some View {
        Page {
            if let problem = store.problem { Text(problem).foregroundStyle(Theme.danger).padding(.bottom, 16) }
            if store.entries.isEmpty { empty } else { filled }
        }
        .sheet(item: $editing) { entry in
            EditSheet(entry: entry) { store.correct(entry, to: $0) }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Settings.retention == .off ? "History is off" : "Hold \(keyLabel) and talk").font(Theme.display).tracking(-0.8)
            Text(Settings.retention == .off ? "Choose how long to keep it in Settings." : "Click into any text field first. Let go, and your words are typed there and kept here, on this Mac only.")
                .font(Theme.reading).foregroundStyle(Theme.muted).lineSpacing(4)
        }
        .padding(.top, 48)
    }

    @ViewBuilder private var filled: some View {
        let stats = DictationStats(store.entries)
        HStack(spacing: 40) {
            Stat(value: stats.words.formatted(), label: "words")
            Stat(value: "\(stats.wordsPerMinute)", label: "words a minute")
            Stat(value: String(format: "%.1f s", Double(stats.medianMs) / 1000), label: "usual wait")
            Spacer()
        }
        .padding(.bottom, 24)
        GraphiteField(prompt: "Search", text: $query, icon: "magnifyingglass")
        if shown.isEmpty { Text("Nothing matches \u{201C}\(query)\u{201D}.").foregroundStyle(Theme.muted).padding(.top, 24) }
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(days, id: \.day) { group in
                SectionLabel(Self.label(group.day))
                ForEach(group.entries) { entry in
                    HistoryRow(entry: entry, edit: { editing = entry }, delete: { store.delete(entry) })
                    Hairline()
                }
            }
        }
    }

    private static func label(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month().day())
    }
}

private struct HistoryRow: View {
    let entry: Dictation
    let edit: () -> Void
    let delete: () -> Void
    @State private var isHovered = false
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.outcome == .typed {
                Text(entry.finalText).font(Theme.reading).lineSpacing(4).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(entry.problem ?? "Nothing typed").font(Theme.reading).foregroundStyle(entry.outcome == .failed ? Theme.danger : Theme.muted)
            }
            HStack(spacing: 12) {
                Text(entry.date.formatted(date: .omitted, time: .shortened)).monospacedDigit()
                Text(entry.app)
                if entry.corrected != nil { Text("Corrected") }
                Spacer()
                actions.opacity(isHovered || isCopied ? 1 : 0)
            }
            .font(Theme.small).foregroundStyle(Theme.muted)
            .frame(height: Theme.smallControlHeight)
        }
        .padding(.top, 14).padding(.bottom, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var actions: some View {
        HStack(spacing: 2) {
            if entry.outcome == .typed {
                Button("Correct", action: edit).graphite(.ghost, small: true)
                Button(isCopied ? "Copied" : "Copy", action: copy).graphite(.ghost, small: true)
            }
            Button("Delete", action: delete).graphite(.ghost, small: true)
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.finalText, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCopied = false }
    }
}

private struct EditSheet: View {
    let entry: Dictation
    let save: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What did you mean?").font(Theme.title)
            TextEditor(text: $text).font(Theme.body).frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.border))
            Text("It heard: \(entry.heard)").font(Theme.small).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.graphite().keyboardShortcut(.cancelAction)
                Button("Save correction") { save(text); dismiss() }.graphite(.primary).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 480).background(Theme.background).foregroundStyle(Theme.text)
        .onAppear { text = entry.finalText }
    }
}
