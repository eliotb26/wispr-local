import SwiftUI
import WisprLocalCore

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var opensAtLogin = Settings.opensAtLogin
    @State private var playSound = Settings.playSound
    @State private var retention = Settings.retention
    @State private var keepAudio = Settings.keepAudio
    @State private var useClaude = Settings.useClaude
    @State private var isConfirmingDelete = false
    @State private var problem: String?

    var body: some View {
        Page(title: "Settings", subtitle: problem) {
            Group {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Appearance").padding(.top, -32)
                    Card {
                        GraphiteRow(title: "Theme", isLast: true) {
                            Picker("", selection: $state.look) { ForEach(Look.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                .pickerStyle(.segmented).labelsHidden().fixedSize()
                        }
                    }
                    SectionLabel("Dictation")
                    Card {
                    GraphiteRow(title: "Hold to talk") {
                        Picker("", selection: Binding(get: { state.key }, set: { state.key = $0; Settings.key = $0 })) {
                            ForEach([HotKey.fn, .rightOption], id: \.self) { Text($0.label).tag($0) }
                        }
                        .labelsHidden().fixedSize()
                    }
                    toggle("Open at login", nil, $opensAtLogin) { isOn in
                        guard isOn != Settings.opensAtLogin else { return }
                        do {
                            try Settings.setOpensAtLogin(isOn)
                        } catch {
                            log("open at login: \(error)")
                            problem = "Couldn't change Open at login: \(error.localizedDescription)"
                            opensAtLogin = Settings.opensAtLogin
                        }
                    }
                    toggle("Sound when you let go", nil, $playSound, isLast: true) { Settings.playSound = $0 }
                    }
                    SectionLabel("Privacy")
                    Card {
                    GraphiteRow(title: "Keep history", detail: "Skips password fields macOS can detect.") {
                        Picker("", selection: $retention) { ForEach(Retention.allCases, id: \.self) { Text($0.label).tag($0) } }
                            .labelsHidden().fixedSize()
                            .onChange(of: retention) { Settings.retention = $0; state.history.purge() }
                    }
                    toggle("Keep recordings", "For measuring and training on your voice. Deleted with their history entry.", $keepAudio) { Settings.keepAudio = $0 }
                    toggle("Use Claude for hard edits", "Sends those transcripts, the app's name and nearby text to Claude.", $useClaude) { Settings.useClaude = $0 }
                    GraphiteRow(title: "Delete everything saved", detail: "History, recordings and timings. Voice test files stay.", isLast: true) {
                        Button("Delete\u{2026}", role: .destructive) { isConfirmingDelete = true }.graphite(.danger)
                    }
                    }
                    SectionLabel("Help")
                    Card {
                    GraphiteRow(title: "Something not working?", detail: "The log never holds what you said.", isLast: true) {
                        Button("Show log") { NSWorkspace.shared.open(Paths.log) }.graphite()
                    }
                    }
                }
            }
        }
        .confirmationDialog("Delete all history and recordings?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) { state.onDeleteAll(); problem = state.history.problem }
        }
    }

    private func toggle(_ title: String, _ detail: String?, _ value: Binding<Bool>, isLast: Bool = false, change: @escaping (Bool) -> Void) -> some View {
        GraphiteRow(title: title, detail: detail, isLast: isLast) {
            Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.small).onChange(of: value.wrappedValue, perform: change)
        }
    }
}
