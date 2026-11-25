import SwiftUI
import WisprLocalCore

/// Totals, rank and this week, beside Home.
struct ProgressCard: View {
    let totals: Totals

    var body: some View {
        let rank = Rank(words: totals.words), now = Date()
        Card {
            VStack(alignment: .leading, spacing: 10) {
                figure(totals.words.formatted(.number.notation(.compactName)), "total words")
                figure("\(totals.wordsPerMinute)", "words a minute")
                figure("\(totals.streak(now: now))", "day streak")
                HStack(spacing: 0) {
                    ForEach(totals.week(now: now), id: \.date) { day in
                        VStack(spacing: 4) {
                            Circle().fill(day.isActive ? Theme.accent : Theme.active).frame(width: 18, height: 18)
                                .overlay { if day.isActive { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) } }
                            Text(day.date.formatted(.dateTime.weekday(.narrow))).font(Theme.caption).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide))), \(day.isActive ? "talked" : "nothing")")
                    }
                }
                .padding(.vertical, 6)
                Hairline()
                VStack(alignment: .leading, spacing: 8) {
                    Text(rank.rawValue).font(Theme.bodyMedium)
                    Meter(value: rank.progress(at: totals.words))
                    Text(rank.next.map { "\(($0.words - totals.words).formatted()) words to \($0.rawValue)" } ?? "The top rank")
                        .font(Theme.small).foregroundStyle(Theme.muted).monospacedDigit()
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
            }
            .padding(16)
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value).font(Theme.page).tracking(-0.6).monospacedDigit().countsUp(value)
            Text(label).font(Theme.small).foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

struct Meter: View {
    let value: Double
    var body: some View {
        GeometryReader { space in
            Capsule().fill(Theme.active)
            Capsule().fill(Theme.accent).frame(width: value > 0 ? max(6, space.size.width * value) : 0)
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Every rank, with the ones earned filled in.
struct RankLadder: View {
    let words: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Rank.allCases, id: \.self) { rank in
                let isEarned = words >= rank.words
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: isEarned ? "checkmark.seal.fill" : "lock").foregroundStyle(isEarned ? Theme.accent : Theme.placeholder).frame(height: 20)
                    Text(rank.rawValue).font(Theme.smallMedium).lineLimit(1).minimumScaleFactor(0.8)
                    Text(rank.words == 0 ? "Start" : rank.words.formatted(.number.notation(.compactName))).font(Theme.caption).foregroundStyle(Theme.muted)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isEarned ? Theme.accentSubtle : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isEarned ? .clear : Theme.border))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Says so, once, when a rank is reached.
struct RankToast: View {
    @ObservedObject var store: HistoryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let rank = store.newRank {
                HStack(spacing: 10) {
                    LogoMark().frame(width: 20, height: 20)
                    Text("You're a \(rank.rawValue) now").font(Theme.bodyMedium)
                }
                .padding(.horizontal, 18).frame(height: 44)
                .background(Capsule().fill(Theme.raised).shadow(color: .black.opacity(0.16), radius: 16, y: 6))
                .overlay(Capsule().strokeBorder(Theme.border))
                .padding(.bottom, 24)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                .task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    store.newRank = nil
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 1), value: store.newRank)
    }
}

/// Things worth setting up. Each is checked against what is really there.
struct Step: Identifiable {
    let id: String
    let title: String
    let pitch: String
    let button: String
    let isDone: Bool
    let open: () -> Void
}

struct StepsCard: View {
    let steps: [Step]
    let hide: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Make it yours").font(Theme.bodyMedium).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: hide) { Image(systemName: "xmark") }.graphite(.ghost, small: true).accessibilityLabel("Hide these steps")
                }
                Meter(value: Double(steps.filter(\.isDone).count) / Double(max(1, steps.count)))
                ForEach(steps) { step in
                    Button(action: step.open) {
                        HStack(spacing: 10) {
                            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle").font(.system(size: 16))
                                .foregroundStyle(step.isDone ? Theme.accent : Theme.borderStrong)
                            Text(step.title).foregroundStyle(step.isDone ? Theme.muted : Theme.text)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityValue(step.isDone ? "Done" : "Not done")
                }
            }
            .padding(16)
        }
    }
}

/// The next step worth taking, with one button.
struct StepBanner: View {
    let step: Step

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title).font(Theme.bodyMedium)
                Text(step.pitch).font(Theme.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(step.button, action: step.open).graphite(.primary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accentSubtle))
    }
}
