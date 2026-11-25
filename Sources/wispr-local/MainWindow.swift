import AppKit
import Combine
import SwiftUI
import WisprLocalCore

enum Section: String, CaseIterable {
    case home = "Home", history = "History", insights = "Insights", words = "Words"
    case snippets = "Snippets", style = "Style", scratchpad = "Scratchpad"

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock.arrow.circlepath"
        case .insights: return "chart.bar"
        case .words: return "character.book.closed"
        case .snippets: return "text.insert"
        case .style: return "textformat"
        case .scratchpad: return "note.text"
        }
    }
}

/// Light, dark, or whatever the Mac uses.
enum Look: String, CaseIterable {
    case light = "Light", dark = "Dark", system = "Match Mac"

    var appearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }
}

/// What the window shows, shared with the app.
final class AppState: ObservableObject {
    @Published var section = Section.home
    @Published var status = "Starting\u{2026}"
    @Published var isReady = false
    @Published var key: HotKey
    lazy var history = HistoryStore() // created only by the app, not the command-line tool
    @Published var look = Settings.look { didSet { Settings.look = look } }
    /// The open settings tab, if any. Opening takes focus from whatever was being typed into.
    @Published var settings: SettingsTab? {
        didSet { if oldValue == nil, settings != nil { NSApp.keyWindow?.makeFirstResponder(nil) } }
    }
    lazy var snippets = SnippetStore()
    lazy var notes = NoteStore()
    lazy var words = WordStore()
    let voiceTest = VoiceTest()
    let voice = LiveVoice()
    let profile = Profile()
    var onDeleteAll: () -> Void = {}

    init(key: HotKey) { self.key = key }
}

/// The app's window. The Dock icon shows only while it is open.
final class MainWindow: NSObject, NSWindowDelegate {
    private let state: AppState
    private lazy var window = makeWindow()
    private var lookObserver: AnyCancellable?

    init(state: AppState) { self.state = state }

    /// Where recordings go while the voice test is on screen and in front.
    var captureTarget: (([Float]) -> Void)? {
        guard NSApp.isActive, window.isVisible, state.settings == .voice, !state.voiceTest.isDone, !state.voiceTest.isTuning else { return nil }
        return state.voiceTest.save
    }

    func show(_ section: Section? = nil) {
        if let section { state.section = section }
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 740),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = Paths.appName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 980, height: 620)
        window.delegate = self
        let content = NSHostingView(rootView: RootView(state: state))
        content.sizingOptions = [] // the window keeps its size when the page changes
        window.contentView = content
        lookObserver = state.$look.sink { [weak window] in window?.appearance = $0.appearance }
        window.center()
        window.setFrameAutosaveName("main-window")
        return window
    }
}

private struct RootView: View {
    @ObservedObject var state: AppState
    @ObservedObject var profile: Profile
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(state: AppState) {
        self.state = state
        profile = state.profile
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 216)
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border))
                .overlay(alignment: .topTrailing) { lookButton.padding(12) }
                .padding([.vertical, .trailing], 8)
        }
        .background(Theme.window)
        .disabled(state.settings != nil)
        .accessibilityHidden(state.settings != nil)
        .overlay { SettingsModal(state: state, profile: profile) }
        .overlay(alignment: .bottom) { RankToast(store: state.history) }
        .ignoresSafeArea()
        .font(Theme.body)
        .foregroundStyle(Theme.text)
        .tint(Theme.control)
    }

    private var page: some View {
        Group {
            switch state.section {
            case .home: HomeView(state: state, store: state.history, profile: profile, voice: state.voice, words: state.words, snippets: state.snippets)
            case .history: HistoryView(store: state.history, keyLabel: state.key.label)
            case .insights: InsightsView(store: state.history)
            case .words: WordsView(words: state.words)
            case .snippets: SnippetsView(store: state.snippets)
            case .style: StyleView()
            case .scratchpad: ScratchpadView(store: state.notes)
            }
        }
        .id(state.section)
        .transition(.opacity)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                LogoMark().frame(width: 22, height: 22)
                Text(Paths.appName).font(.custom("Geist-SemiBold", fixedSize: 16)).tracking(-0.3)
                Button { state.settings = .plan } label: {
                    Text("Free").font(Theme.captionStrong).foregroundStyle(Theme.accentText).padding(.horizontal, 7).frame(height: 20)
                        .background(Capsule().fill(Theme.accentSubtle))
                }
                .buttonStyle(PressStyle()).accessibilityLabel("Your plan: Free")
            }
            .padding(.horizontal, 12).padding(.top, 52).padding(.bottom, 20)
            ForEach(Array(Section.allCases.enumerated()), id: \.element) { index, section in
                row(section).keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            Spacer()
            if !state.isReady {
                Text(state.status).font(Theme.small).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true).padding(12)
            }
            Button { state.settings = .general } label: { label("Settings", "gearshape") }
                .buttonStyle(SidebarButton(isSelected: false, selection: selection, height: 36)).keyboardShortcut(",", modifiers: .command)
            Button { state.settings = .profile } label: {
                HStack(spacing: 10) {
                    Avatar(initials: profile.initials, size: 28)
                    Text(profile.name.isEmpty ? "Your profile" : profile.name).font(Theme.bodyMedium).lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(SidebarButton(isSelected: false, selection: selection, height: 44)).accessibilityLabel("Profile")
        }
        .padding(.horizontal, 8).padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ section: Section) -> some View {
        Button { select(section) } label: {
            label(section.rawValue, section.icon)
        }
        .buttonStyle(SidebarButton(isSelected: state.section == section, selection: selection, height: 36))
        .accessibilityAddTraits(state.section == section ? .isSelected : [])
    }

    private func label(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).frame(width: 20)
            Text(title).font(Theme.bodyMedium)
            Spacer(minLength: 0)
        }
    }

    private func select(_ section: Section) {
        let isKeyboard = NSApp.currentEvent?.type == .keyDown // shortcuts switch instantly
        withAnimation(reduceMotion || isKeyboard ? nil : .spring(response: 0.28, dampingFraction: 1)) { state.section = section }
    }

    private var lookButton: some View {
        LookButton { state.look = $0 }
    }
}

private struct LookButton: View {
    let choose: (Look) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button { choose(scheme == .dark ? .light : .dark) } label: {
            Image(systemName: scheme == .dark ? "sun.max" : "moon")
        }
        .graphite(.ghost, small: true)
        .accessibilityLabel(scheme == .dark ? "Use light mode" : "Use dark mode")
    }
}

private struct SidebarButton: ButtonStyle {
    let isSelected: Bool
    let selection: Namespace.ID
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration, isSelected: isSelected, selection: selection, height: height)
    }

    private struct Row: View {
        let configuration: Configuration
        let isSelected: Bool
        let selection: Namespace.ID
        let height: CGFloat
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isSelected ? Theme.text : isHovered ? Theme.text : Theme.muted)
                .padding(.horizontal, 10).frame(height: height)
                .background {
                    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
                    if isSelected {
                        shape.fill(Theme.raised).shadow(color: .black.opacity(0.07), radius: 3, y: 1).matchedGeometryEffect(id: "selected", in: selection)
                    } else if isHovered {
                        shape.fill(Theme.active.opacity(0.7))
                    }
                }
                .contentShape(Rectangle())
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .onHover { isHovered = $0 }
        }
    }
}

/// Speech bars in the voice colors.
struct LogoMark: View {
    private static let heights: [CGFloat] = [0.36, 0.82, 0.56, 0.3]
    var body: some View {
        GeometryReader { space in
            LinearGradient(colors: [Theme.cobalt, Theme.sky, Theme.mint], startPoint: .leading, endPoint: .trailing)
                .mask {
                    HStack(spacing: space.size.width * 0.1) {
                        ForEach(Self.heights.indices, id: \.self) { Capsule().frame(height: space.size.height * Self.heights[$0]) }
                    }
                }
        }
        .accessibilityHidden(true)
    }
}
