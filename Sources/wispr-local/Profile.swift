import SwiftUI
import WisprLocalCore

/// The person using the app. Kept on this Mac; there is no account.
final class Profile: ObservableObject {
    private static let key = "profileName"
    @Published var name: String { didSet { UserDefaults.standard.set(name, forKey: Self.key) } }

    init() { name = UserDefaults.standard.string(forKey: Self.key) ?? NSFullUserName() }

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? "" }
    var initials: String { name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased() }
}

struct Avatar: View {
    let initials: String
    var size: CGFloat = 32

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [Theme.cobalt, Theme.sky, Theme.mint], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Text(initials.isEmpty ? "?" : initials).font(.custom("Geist-SemiBold", fixedSize: size * 0.36)).foregroundStyle(.white))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct ProfileView: View {
    @ObservedObject var profile: Profile
    @ObservedObject var store: HistoryStore

    var body: some View {
        let stats = DictationStats(store.entries), insights = Insights(store.entries, now: Date())
        Page(title: "Profile") {
            Card {
                HStack(spacing: 20) {
                    Avatar(initials: profile.initials, size: 72)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your name").font(Theme.smallMedium).foregroundStyle(Theme.muted)
                        GraphiteField(prompt: "Name", text: $profile.name)
                    }
                }
                .padding(20)
            }
            SectionLabel("Your voice")
            Card {
                GraphiteRow(title: "Speaking pace") { value(stats.wordsPerMinute == 0 ? "Not enough yet" : "\(stats.wordsPerMinute) words a minute") }
                GraphiteRow(title: "Where you talk most") { value(insights.apps.first?.name ?? "Not enough yet") }
                GraphiteRow(title: "Corrections you've made", isLast: true) { value(insights.corrected.formatted()) }
            }
            Text("Your profile stays on this Mac. There is no account.").font(Theme.small).foregroundStyle(Theme.muted).padding(.top, 12)
        }
    }

    private func value(_ text: String) -> some View { Text(text).foregroundStyle(Theme.muted).monospacedDigit() }
}
