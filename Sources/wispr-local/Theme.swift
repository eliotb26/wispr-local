import SwiftUI

/// Graphite design roles, light and dark, plus the aurora colors that mean "voice".
enum Theme {
    static let cobalt = role(0x2763D7, 0x2763D7), sky = role(0x6CC5FF, 0x6CC5FF), mint = role(0x8FEBD0, 0x8FEBD0), lemon = role(0xF3F6A6, 0xF3F6A6)
    static let raised = role(0xFFFFFF, 0x202326)
    static let window = role(0xF1F4F8, 0x0D0E10)
    static let background = role(0xFFFFFF, 0x0D0E10)
    static let subtle = role(0xF5F8FB, 0x131416)
    static let hover = role(0xEDF0F5, 0x1A1C1F)
    static let border = role(0xD6DBE2, 0x2D3136)
    static let text = role(0x1D1F23, 0xEBEFF4)
    static let muted = role(0x5F646A, 0xB0B5BB)
    static let accent = role(0x2763D7, 0x3C72DA)
    static let accentSubtle = role(0xE7EFFE, 0x162137)
    static let accentText = role(0x335FB4, 0xA5C5FF)
    /// Switches, progress and focus: dark enough to see on white.
    static let control = role(0x2763D7, 0x3C72DA)
    static let onAccent = Color.white
    static let warning = role(0x8A5600, 0xF4A437)
    static let danger = role(0xC9302D, 0xEC5C52)
    static let borderStrong = role(0xB4B9C1, 0x4C5157)
    static let surface = role(0xFFFFFF, 0x131416)
    static let placeholder = role(0x878D94, 0x646970)
    static let active = role(0xE6EAEF, 0x202326)
    static let accentHover = role(0x1A54C8, 0x477EE8)
    static let dangerSubtle = role(0xFBE9E8, 0x2E1413)
    static let success = role(0x1D7D3E, 0x4CB86A)

    // The type scale: 12, 13, 14, 20, 24, 32.
    static let caption = font(12), small = font(13), body = font(14), reading = font(16), smallMedium = font(13, "Medium"), bodyMedium = font(14, "Medium")
    static let captionStrong = font(12, "SemiBold"), title = font(20, "SemiBold"), page = font(24, "SemiBold"), display = font(32, "SemiBold")
    static let controlHeight: CGFloat = 32, smallControlHeight: CGFloat = 28, radius: CGFloat = 6, smallRadius: CGFloat = 4

    private static func font(_ size: CGFloat, _ weight: String = "Regular") -> Font { .custom("Geist-\(weight)", fixedSize: size) }

    private static func role(_ light: Int, _ dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { color($0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light) })
    }

    private static func color(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

/// One centered reading column under the top bar.
struct Page<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    Text(title).font(Theme.page).tracking(-0.4).accessibilityAddTraits(.isHeader)
                    if let subtitle { Text(subtitle).font(Theme.body).foregroundStyle(Theme.muted).padding(.top, 4) }
                    Spacer().frame(height: 24)
                }
                content
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 40).padding(.top, 44).padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Theme.smallMedium).foregroundStyle(Theme.muted).padding(.top, 32).padding(.bottom, 8).accessibilityAddTraits(.isHeader)
    }
}

/// A raised group of rows.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.border))
    }
}

/// A key on the keyboard.
struct KeyCap: View {
    let label: String
    var isLarge = false
    var body: some View {
        Text(label).font(isLarge ? Theme.title : Theme.captionStrong).foregroundStyle(Theme.text).shadow(color: .clear, radius: 0)
            .padding(.horizontal, isLarge ? 12 : 6).frame(height: isLarge ? 36 : 20)
            .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius).strokeBorder(Theme.borderStrong))
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.border).frame(height: 1) }
}

/// The Graphite button. Primary is for a view's one main action.
struct GraphiteButton: ButtonStyle {
    enum Kind { case secondary, primary, ghost, danger }
    var kind = Kind.secondary
    var isSmall = false

    func makeBody(configuration: Configuration) -> some View {
        GraphiteButtonBody(kind: kind, isSmall: isSmall, configuration: configuration)
    }
}

private struct GraphiteButtonBody: View {
    let kind: GraphiteButton.Kind
    let isSmall: Bool
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isSmall ? Theme.smallRadius : Theme.radius)
        configuration.label
            .font(isSmall ? Theme.smallMedium : Theme.bodyMedium)
            .foregroundStyle(foreground)
            .padding(.horizontal, isSmall ? 8 : 12)
            .frame(height: isSmall ? Theme.smallControlHeight : Theme.controlHeight)
            .background(shape.fill(background))
            .overlay(shape.strokeBorder(border))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = $0 && isEnabled }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.onAccent
        case .danger: return Theme.danger
        case .ghost: return isHovered ? Theme.text : Theme.muted
        case .secondary: return Theme.text
        }
    }

    private var background: Color {
        if kind == .primary { return isHovered ? Theme.accentHover : Theme.accent }
        if configuration.isPressed { return Theme.active }
        if isHovered { return kind == .danger ? Theme.dangerSubtle : Theme.hover }
        return kind == .ghost ? .clear : Theme.surface
    }

    private var border: Color {
        switch kind {
        case .primary: return Theme.accent
        case .ghost: return .clear
        case .danger: return isHovered ? Theme.danger : Theme.borderStrong
        case .secondary: return Theme.borderStrong
        }
    }
}

extension View {
    func graphite(_ kind: GraphiteButton.Kind = .secondary, small: Bool = false) -> some View {
        buttonStyle(GraphiteButton(kind: kind, isSmall: small))
    }
}

/// The Graphite text input, with its focus ring.
struct GraphiteField: View {
    let prompt: String
    @Binding var text: String
    var icon: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon).foregroundStyle(Theme.muted).accessibilityHidden(true) }
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundColor(Theme.placeholder)).textFieldStyle(.plain).font(Theme.body).focused($isFocused)
        }
        .padding(.horizontal, 12).frame(height: Theme.controlHeight)
        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(isFocused ? Theme.control : Theme.borderStrong))
        .background(RoundedRectangle(cornerRadius: Theme.radius + 3).fill(isFocused ? Theme.accentSubtle : .clear).padding(-3))
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

/// A setting or record: words on the left, its control on the right, a hairline below.
struct GraphiteRow<Control: View>: View {
    let title: String
    var detail: String?
    var isLast = false
    @ViewBuilder let control: Control

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.bodyMedium)
                    if let detail { Text(detail).font(Theme.small).foregroundStyle(Theme.muted) }
                }
                Spacer()
                control
            }
            .frame(minHeight: 36)
            .padding(.vertical, 8)
            if !isLast { Hairline() }
        }
        .padding(.horizontal, 20)
    }
}
