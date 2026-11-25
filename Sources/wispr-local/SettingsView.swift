import SwiftUI
import WisprLocalCore

enum SettingsTab: String, CaseIterable {
    case general = "General", voice = "Your voice", connections = "Connections", privacy = "Privacy"
    case profile = "Account", plan = "Plan and spend"

    static let app: [SettingsTab] = [.general, .voice, .connections, .privacy]
    static let you: [SettingsTab] = [.profile, .plan]

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .voice: return "waveform"
        case .connections: return "powerplug"
        case .privacy: return "lock.shield"
        case .profile: return "person.crop.circle"
        case .plan: return "creditcard"
        }
    }
}

/// Settings over the window, with its own tabs. Escape or a click outside closes it.
struct SettingsModal: View {
    @ObservedObject var state: AppState
    @ObservedObject var profile: Profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let tab = state.settings {
                Color.black.opacity(0.28).onTapGesture(perform: close).accessibilityHidden(true).transition(.opacity)
                HStack(spacing: 0) {
                    tabs(tab).frame(width: 200).background(Theme.window)
                    Rectangle().fill(Theme.border).frame(width: 1)
                    pane(tab).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background)
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: close) { Image(systemName: "xmark") }.graphite(.ghost, small: true).keyboardShortcut(.cancelAction)
                        .accessibilityLabel("Close settings").padding(12)
                }
                .frame(maxWidth: 860, maxHeight: 600)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.border))
                .shadow(color: .black.opacity(0.22), radius: 32, y: 12)
                .padding(40)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
                .accessibilityAddTraits(.isModal)
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.settings == nil)
    }

    private func close() { state.settings = nil }

    private func tabs(_ current: SettingsTab) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            heading("Settings").padding(.top, 20)
            ForEach(SettingsTab.app, id: \.self) { row($0, current) }
            heading("You").padding(.top, 16)
            ForEach(SettingsTab.you, id: \.self) { row($0, current) }
            Spacer()
            Text("\(Paths.appName) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(Theme.caption).foregroundStyle(Theme.muted).padding(10)
        }
        .padding(.horizontal, 8).padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(Theme.smallMedium).foregroundStyle(Theme.muted).padding(.horizontal, 10).padding(.bottom, 6).accessibilityAddTraits(.isHeader)
    }

    private func row(_ tab: SettingsTab, _ current: SettingsTab) -> some View {
        Button { state.settings = tab } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon).font(.system(size: 13, weight: .medium)).frame(width: 20)
                Text(tab.rawValue).font(Theme.bodyMedium)
                Spacer(minLength: 0)
            }
            .foregroundStyle(tab == current ? Theme.text : Theme.muted)
            .padding(.horizontal, 10).frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tab == current ? Theme.raised : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(tab == current ? .isSelected : [])
    }

    @ViewBuilder private func pane(_ tab: SettingsTab) -> some View {
        switch tab {
        case .general: GeneralPane(state: state)
        case .voice: VoicePane(test: state.voiceTest, voice: state.voice, words: state.words, keyLabel: state.key.label)
        case .connections: ConnectionsPane()
        case .privacy: PrivacyPane(state: state)
        case .profile: ProfilePane(profile: profile, store: state.history)
        case .plan: PlanPane(store: state.history)
        }
    }
}

/// One settings tab.
struct Pane<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(Theme.page).tracking(-0.4).accessibilityAddTraits(.isHeader)
                if let subtitle { Text(subtitle).foregroundStyle(Theme.muted).padding(.top, 4).fixedSize(horizontal: false, vertical: true) }
                Spacer().frame(height: 24)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32).padding(.top, 36).padding(.bottom, 32)
        }
    }
}

private struct SwitchRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool
    var isLast = false
    let change: (Bool) -> Void

    var body: some View {
        GraphiteRow(title: title, detail: detail, isLast: isLast) {
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small).onChange(of: isOn, perform: change)
        }
    }
}

private struct GeneralPane: View {
    @ObservedObject var state: AppState
    @State private var opensAtLogin = Settings.opensAtLogin
    @State private var playSound = Settings.playSound
    @State private var problem: String?

    var body: some View {
        Pane(title: "General", subtitle: problem) {
            Card {
                GraphiteRow(title: "Hold to talk") {
                    Picker("", selection: Binding(get: { state.key }, set: { state.key = $0; Settings.key = $0 })) {
                        ForEach([HotKey.fn, .rightOption], id: \.self) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
                SwitchRow(title: "Open at login", isOn: $opensAtLogin, change: setOpensAtLogin)
                SwitchRow(title: "Sound when you let go", isOn: $playSound) { Settings.playSound = $0 }
                GraphiteRow(title: "Theme") {
                    Picker("", selection: $state.look) { ForEach(Look.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                GraphiteRow(title: "Something not working?", detail: "The log never holds what you said.", isLast: true) {
                    Button("Show log") { NSWorkspace.shared.open(Paths.log) }.graphite()
                }
            }
        }
    }

    private func setOpensAtLogin(_ isOn: Bool) {
        guard isOn != Settings.opensAtLogin else { return }
        do {
            try Settings.setOpensAtLogin(isOn)
        } catch {
            log("open at login: \(error)")
            problem = "Couldn't change Open at login: \(error.localizedDescription)"
            opensAtLogin = Settings.opensAtLogin
        }
    }
}

private struct PrivacyPane: View {
    @ObservedObject var state: AppState
    @State private var retention = Settings.retention
    @State private var keepAudio = Settings.keepAudio
    @State private var isConfirmingDelete = false
    @State private var problem: String?

    var body: some View {
        Pane(title: "Privacy", subtitle: problem ?? "Speech is turned into text on this Mac.") {
            Card {
                GraphiteRow(title: "Keep history", detail: "Skips password fields macOS can detect.") {
                    Picker("", selection: $retention) { ForEach(Retention.allCases, id: \.self) { Text($0.label).tag($0) } }
                        .labelsHidden().fixedSize()
                        .onChange(of: retention) { Settings.retention = $0; state.history.purge() }
                }
                SwitchRow(title: "Keep recordings", detail: "Deleted with their history entry.", isOn: $keepAudio) { Settings.keepAudio = $0 }
                GraphiteRow(title: "Delete all dictations", detail: "History, recordings, timings, rank and streak. Words, snippets, notes and voice recordings stay.", isLast: true) {
                    Button("Delete\u{2026}", role: .destructive) { isConfirmingDelete = true }.graphite(.danger)
                }
            }
            Text("Word counts and the days you talked are kept for your rank and streak after history expires. They never include what you said. With Don't save, nothing is counted.")
                .font(Theme.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true).padding(.top, 12)
        }
        .confirmationDialog("Delete all history and recordings?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) { state.onDeleteAll(); problem = state.history.problem }
        }
    }
}

private struct PlanPane: View {
    @ObservedObject var store: HistoryStore
    private static let included = ["Unlimited dictation on this Mac", "Snippets, styles and scratchpad", "Connections to your AI apps"]

    var body: some View {
        let month = store.totals.month(Date())
        Pane(title: "Plan and spend") {
            Card {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(0.formatted(.currency(code: "USD"))).font(Theme.display).tracking(-0.8).monospacedDigit()
                        Text("spent in \(Date().formatted(.dateTime.month(.wide)))").font(Theme.small).foregroundStyle(Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    Text("Free").font(Theme.captionStrong).foregroundStyle(Theme.accentText).padding(.horizontal, 8).frame(height: 22)
                        .background(Capsule().fill(Theme.accentSubtle))
                }
                .padding(20)
                Hairline()
                GraphiteRow(title: "Words this month") { value(month.words) }
                GraphiteRow(title: "Edits sent to Claude", detail: "Uses your own Claude plan. Its cost isn't counted here.", isLast: true) { value(month.claudeEdits) }
            }
            SectionLabel("Included")
            Card {
                VStack(alignment: .leading, spacing: 12) { ForEach(Self.included, id: \.self) { Label($0, systemImage: "checkmark") } }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("No card is on file, so nothing can be charged.").font(Theme.small).foregroundStyle(Theme.muted).padding(.top, 12)
        }
    }

    private func value(_ number: Int) -> some View { Text(number.formatted()).foregroundStyle(Theme.muted).monospacedDigit().countsUp("\(number)") }
}
