import SwiftUI
import WisprLocalCore

struct StyleView: View {
    @State private var group = AppGroup.messages
    @State private var styles = Dictionary(uniqueKeysWithValues: AppGroup.allCases.map { ($0, Settings.style(for: $0)) })
    private static let sample = "Hey Sam, I can do Friday. Does three still work? See you then."

    var body: some View {
        Page(title: "Style", subtitle: "Punctuation and capitals for each kind of app. Your words never change.") {
            Picker("Apps", selection: $group) { ForEach(AppGroup.allCases, id: \.self) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 440)
            Text(group.detail).font(Theme.small).foregroundStyle(Theme.muted).padding(.top, 8).padding(.bottom, 20)
            HStack(alignment: .top, spacing: 12) { ForEach(WritingStyle.allCases, id: \.self, content: card) }
        }
    }

    private func card(_ style: WritingStyle) -> some View {
        let isChosen = styles[group] == style
        return Button {
            Settings.setStyle(style, for: group)
            styles = styles.merging([group: style]) { $1 }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(style.title).font(Theme.title).tracking(-0.3)
                    Spacer()
                    Image(systemName: isChosen ? "checkmark.circle.fill" : "circle").foregroundStyle(isChosen ? Theme.accent : Theme.borderStrong)
                }
                Text(style.apply(to: Self.sample)).lineSpacing(4).multilineTextAlignment(.leading).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(20).frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isChosen ? Theme.accentSubtle : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isChosen ? Theme.accent : Theme.border, lineWidth: isChosen ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.98 : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension WritingStyle {
    var title: String {
        switch self {
        case .polished: return "Polished"
        case .relaxed: return "Relaxed"
        case .lowercase: return "lowercase"
        }
    }
}

private extension AppGroup {
    var title: String {
        switch self {
        case .messages: return "Messages"
        case .work: return "Work chat"
        case .email: return "Email"
        case .other: return "Everything else"
        }
    }

    var detail: String {
        switch self {
        case .messages: return "Messages, WhatsApp, Telegram, Signal, Discord"
        case .work: return "Slack, Teams, Zoom, Roam"
        case .email: return "Mail, Outlook, Superhuman, Spark"
        case .other: return "All other apps, and anything open in a browser"
        }
    }
}
