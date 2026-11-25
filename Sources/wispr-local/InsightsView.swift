import SwiftUI
import WisprLocalCore

struct InsightsView: View {
    @ObservedObject var store: HistoryStore
    @State private var hovered: Date?

    var body: some View {
        let insights = Insights(store.entries, now: Date()), stats = DictationStats(store.entries)
        Page(title: "Insights", subtitle: "From the history kept on this Mac.") {
            Card {
                VStack(alignment: .leading, spacing: 20) {
                    let day = insights.days.first { $0.date == hovered }
                    VStack(alignment: .leading, spacing: 2) {
                        Text((day?.words ?? insights.days.reduce(0) { $0 + $1.words }).formatted()).font(Theme.display).tracking(-0.8).monospacedDigit()
                        Text(day.map { "words on \($0.date.formatted(.dateTime.weekday(.wide).month().day()))" } ?? "words in the last 14 days")
                            .font(Theme.small).foregroundStyle(Theme.muted)
                    }
                    chart(insights.days)
                }
                .padding(20)
            }
            HStack(spacing: 12) {
                StatTile(value: "\(insights.minutesSaved) min", label: "saved over typing at 40 wpm")
                StatTile(value: String(format: "%.1f s", Double(stats.medianMs) / 1000), label: "usual wait")
                StatTile(value: "\(insights.corrected)", label: "corrections")
            }
            .padding(.top, 12)
            SectionLabel("Ranks")
            RankLadder(words: store.totals.words)
            SectionLabel("Where you talk")
            Card {
                if insights.apps.isEmpty { Text("Nothing yet.").foregroundStyle(Theme.muted).padding(20).frame(maxWidth: .infinity, alignment: .leading) }
                let top = insights.apps.prefix(6)
                ForEach(Array(top.enumerated()), id: \.element.id) { index, app in
                    GraphiteRow(title: app.name, isLast: index == top.count - 1) {
                        HStack(spacing: 12) {
                            Capsule().fill(Theme.accent).frame(width: 160 * CGFloat(app.words) / CGFloat(max(1, top.first?.words ?? 1)), height: 6)
                                .frame(width: 160, alignment: .trailing)
                            Text(app.words.formatted()).foregroundStyle(Theme.muted).monospacedDigit().frame(width: 56, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func chart(_ days: [Insights.Day]) -> some View {
        let most = CGFloat(max(1, days.map(\.words).max() ?? 1))
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(day.words == 0 ? Theme.active : hovered == nil || hovered == day.date ? Theme.accent : Theme.accent.opacity(0.35))
                        .frame(height: max(4, 120 * CGFloat(day.words) / most))
                    Text(day.date.formatted(.dateTime.day())).font(Theme.caption).foregroundStyle(Theme.muted).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 148, alignment: .bottom)
                .contentShape(Rectangle())
                .onHover { hovered = $0 ? day.date : hovered == day.date ? nil : hovered }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)), \(day.words) words")
            }
        }
    }
}
