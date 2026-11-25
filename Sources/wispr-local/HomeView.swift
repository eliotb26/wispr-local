import SwiftUI
import WisprLocalCore

struct HomeView: View {
    @ObservedObject var state: AppState
    @ObservedObject var store: HistoryStore
    @ObservedObject var profile: Profile
    @ObservedObject var voice: LiveVoice

    var body: some View {
        let stats = DictationStats(store.entries), insights = Insights(store.entries, now: Date())
        Page {
            Text(profile.firstName.isEmpty ? greeting : "\(greeting), \(profile.firstName)").font(Theme.display).tracking(-0.9)
                .accessibilityAddTraits(.isHeader).padding(.bottom, 20)
            hero
            HStack(spacing: 12) {
                StatTile(value: stats.words.formatted(), label: "words")
                StatTile(value: "\(stats.wordsPerMinute)", label: "words a minute")
                StatTile(value: "\(insights.minutesSaved) min", label: "saved over typing")
                StatTile(value: "\(insights.streak)", label: "day streak")
            }
            .padding(.top, 12)
            HStack {
                SectionLabel("Recent")
                Spacer()
                if !store.entries.isEmpty {
                    Button("See all") { state.section = .history }.graphite(.ghost, small: true).padding(.top, 24)
                }
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
