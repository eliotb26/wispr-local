import SwiftUI
import WisprLocalCore

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    let keyLabel: String
    @State private var query = ""
    @State private var app: String?

    private var shown: [Dictation] { store.entries.filter { $0.matches(query) && (app == nil || $0.app == app) } }

    private var days: [(day: Date, entries: [Dictation])] {
        Dictionary(grouping: shown) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }.map { (day: $0.key, entries: $0.value) }
    }

    var body: some View {
        Page(title: "History") {
            if let problem = store.problem { Text(problem).foregroundStyle(Theme.danger).padding(.bottom, 16) }
            if store.entries.isEmpty { empty } else { filled }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Settings.retention == .off ? "History is off" : "Hold \(keyLabel) and talk").font(Theme.title)
            Text(Settings.retention == .off ? "Choose how long to keep it in Settings." : "Click into any text field first. Let go, and your words are typed there and kept here, on this Mac only.")
                .font(Theme.reading).foregroundStyle(Theme.muted).lineSpacing(4)
        }
            }

    @ViewBuilder private var filled: some View {
        HStack(spacing: 8) {
            GraphiteField(prompt: "Search", text: $query, icon: "magnifyingglass")
            Picker("App", selection: $app) {
                Text("All apps").tag(String?.none)
                ForEach(Array(Set(store.entries.map(\.app))).sorted(), id: \.self) { Text($0).tag(String?.some($0)) }
            }
            .labelsHidden().fixedSize()
            .onChange(of: store.entries.map(\.app)) { apps in
                if let picked = app, !apps.contains(picked) { app = nil }
            }
        }
        if shown.isEmpty { Text("Nothing found.").foregroundStyle(Theme.muted).padding(.top, 24) }
        ForEach(days, id: \.day) { group in
            SectionLabel(Self.label(group.day))
            HistoryList(entries: group.entries, store: store)
        }
    }

    private static func label(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month().day())
    }
}

/// Dictations in a card, newest first. New ones slide in.
struct HistoryList: View {
    let entries: [Dictation]
    @ObservedObject var store: HistoryStore
    @State private var editing: Dictation?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Card {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    HistoryRow(entry: entry, isLast: entry.id == entries.last?.id, edit: { editing = entry }, delete: { store.delete(entry) })
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.spring(response: 0.35, dampingFraction: 1), value: entries.map(\.id))
        .sheet(item: $editing) { entry in EditSheet(entry: entry) { store.correct(entry, to: $0) } }
    }
}

private struct HistoryRow: View {
    let entry: Dictation
    let isLast: Bool
    let edit: () -> Void
    let delete: () -> Void
    @State private var isHovered = false
    @State private var isCopied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(entry.date.formatted(date: .omitted, time: .shortened)).font(Theme.small).foregroundStyle(Theme.muted).monospacedDigit()
                    .frame(width: 64, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    if entry.outcome == .typed {
                        Text(entry.finalText).lineSpacing(3).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label(entry.problem ?? "Nothing typed", systemImage: entry.outcome == .failed ? "exclamationmark.triangle" : "speaker.slash")
                            .foregroundStyle(entry.outcome == .failed ? Theme.danger : Theme.muted)
                    }
                    Text(entry.corrected == nil ? entry.app : "\(entry.app), corrected").font(Theme.small).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .overlay(alignment: .topTrailing) {
                actions.padding(4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised).shadow(color: .black.opacity(0.1), radius: 4, y: 1))
                    .padding(8)
                    .opacity(isHovered || isCopied ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: isHovered)
            }
            if !isLast { Hairline().padding(.leading, 100) }
        }
        .background(isHovered ? Theme.subtle : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            if entry.outcome == .typed {
                icon(isCopied ? "checkmark" : "doc.on.doc", isCopied ? "Copied" : "Copy", copy)
                icon("pencil", "Correct", edit)
            }
            icon("trash", "Delete", delete)
        }
    }

    private func icon(_ name: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: name).frame(width: 16) }.graphite(.ghost, small: true).help(label).accessibilityLabel(label)
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
