import SwiftUI
import WisprLocalCore

struct HomeView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: HistoryStore
    @ObservedObject var profile: Profile
    @ObservedObject var voice: LiveVoice
    @ObservedObject var words: WordStore
    @ObservedObject var snippets: SnippetStore
    @State private var hidesSteps = Settings.hidesSteps
    @State private var isConnected = false

    var body: some View {
        let steps = self.steps, next = steps.first { !$0.isDone }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(profile.firstName.isEmpty ? greeting : "\(greeting), \(profile.firstName)").font(Theme.display).tracking(-0.9).accessibilityAddTraits(.isHeader)
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        hero
                        if !hidesSteps, let next { StepBanner(step: next) }
                        recent
                    }
                    VStack(spacing: 12) {
                        ProgressCard(totals: store.totals)
                        if !hidesSteps, next != nil {
                            StepsCard(steps: steps) { hidesSteps = true; Settings.hidesSteps = true }
                        }
                    }
                    .frame(width: 232)
                }
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: checkConnections)
        .onChange(of: state.settings) { if $0 == nil { checkConnections() } }
    }

    private func checkConnections() { isConnected = ConnectedApp.allCases.contains(where: \.isConnected) }

    private var steps: [Step] {
        [Step(id: "talk", title: "Say something", pitch: "Click in any text box, hold \(state.key.label) and talk.", button: "Try it here",
              isDone: store.totals.words > 0) { state.section = .scratchpad },
         Step(id: "style", title: "Choose your style", pitch: "Casual in messages, polished in email.", button: "Choose",
              isDone: Settings.hasChosenStyle) { state.section = .style },
         Step(id: "words", title: "Teach it a name", pitch: "Add the names and terms it should spell correctly.", button: "Add one",
              isDone: !words.terms.isEmpty) { state.section = .words },
         Step(id: "snippet", title: "Make a snippet", pitch: "Say a short phrase, get your link or sign-off.", button: "Make one",
              isDone: !snippets.items.isEmpty) { state.section = .snippets },
         Step(id: "connect", title: "Connect an AI app", pitch: "Ask Claude or Cursor about what you've dictated.", button: "Connect",
              isDone: isConnected) { state.settings = .connections }]
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel("Recent").padding(.top, -20)
                Spacer()
                if !store.entries.isEmpty { Button("See all") { state.section = .history }.graphite(.ghost, small: true) }
            }
            if store.entries.isEmpty {
                Card { Text("What you dictate shows up here.").foregroundStyle(Theme.muted).padding(20).frame(maxWidth: .infinity, alignment: .leading) }
            } else {
                HistoryList(entries: Array(store.entries.prefix(5)), store: store)
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            VoiceField(voice: voice)
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if voice.isRecording {
                        Text(voice.words.isEmpty ? "Listening\u{2026}" : voice.words).lineLimit(2).truncationMode(.head).frame(maxWidth: 440, alignment: .leading)
                    } else if state.isReady {
                        HStack(spacing: 10) { Text("Hold"); KeyCap(label: state.key.label, isLarge: true); Text("and talk") }
                    } else {
                        Text(state.status).lineLimit(2)
                    }
                }
                .font(.custom("Geist-SemiBold", fixedSize: 28)).tracking(-0.7)
                Spacer()
                Text(voice.isRecording ? "Let go to type it." : "It types wherever your cursor is.").font(Theme.body)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: 8, y: 1)
            .padding(24)
            .animation(.easeOut(duration: 0.18), value: voice.isRecording)
        }
        .frame(height: 188)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.page).tracking(-0.5).monospacedDigit().countsUp(value)
            Text(label).font(Theme.small).foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Rolls digits to their new value where macOS supports it.
    @ViewBuilder func countsUp(_ value: String) -> some View {
        if #available(macOS 14, *) {
            contentTransition(.numericText()).animation(.spring(response: 0.35, dampingFraction: 1), value: value)
        } else {
            self
        }
    }
}
