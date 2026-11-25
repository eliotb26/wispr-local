import AppKit
import SwiftUI
import WisprLocalCore

enum Section: String, CaseIterable {
    case history = "History", words = "Words", voice = "Voice test", settings = "Settings"
}

/// What the window shows, shared with the app.
final class AppState: ObservableObject {
    @Published var section = Section.history
    @Published var status = "Starting\u{2026}"
    @Published var isReady = false
    @Published var key: HotKey
    lazy var history = HistoryStore() // created only by the app, not the command-line tool
    let voiceTest = VoiceTest()
    var onDeleteAll: () -> Void = {}

    init(key: HotKey) { self.key = key }
}

/// The app's window. The Dock icon shows only while it is open.
final class MainWindow: NSObject, NSWindowDelegate {
    private let state: AppState
    private lazy var window = makeWindow()

    init(state: AppState) { self.state = state }

    /// Where recordings go while the voice test is on screen and in front.
    var captureTarget: (([Float]) -> Void)? {
        guard NSApp.isActive, window.isVisible, state.section == .voice, !state.voiceTest.isDone else { return nil }
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
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = Paths.appName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 600, height: 460)
        window.delegate = self
        let content = NSHostingView(rootView: RootView(state: state))
        content.sizingOptions = [] // the window keeps its size when the page changes
        window.contentView = content
        window.center()
        window.setFrameAutosaveName("window")
        return window
    }
}

private struct RootView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Hairline()
            Group {
                switch state.section {
                case .history: HistoryView(store: state.history, keyLabel: state.key.label)
                case .words: WordsView()
                case .voice: VoiceTestView(test: state.voiceTest, keyLabel: state.key.label)
                case .settings: SettingsView(state: state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .background(Theme.background.ignoresSafeArea())
        .font(Theme.body)
        .foregroundStyle(Theme.text)
        .tint(Theme.control)
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 4) {
                ForEach(Array(Section.allCases.enumerated()), id: \.element) { index, section in
                    TabButton(title: section.rawValue, isSelected: state.section == section) { state.section = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            HStack {
                Spacer()
                status
            }
            .padding(.trailing, 16)
        }
        .frame(height: 40) // lines up with the window buttons
    }

    @ViewBuilder private var status: some View {
        if state.isReady {
            HStack(spacing: 6) {
                Text("Hold").font(Theme.small).foregroundStyle(Theme.muted)
                KeyCap(label: state.key.label)
            }
            .accessibilityElement(children: .combine)
        } else {
            Text(state.status).font(Theme.small).foregroundStyle(Theme.warning).lineLimit(2).frame(maxWidth: 150, alignment: .trailing)
        }
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let select: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            Text(title).font(Theme.smallMedium)
                .foregroundStyle(isSelected ? Theme.accentText : isHovered ? Theme.text : Theme.muted)
                .padding(.horizontal, 10).frame(height: Theme.smallControlHeight)
                .background(RoundedRectangle(cornerRadius: Theme.radius).fill(isSelected ? Theme.accentSubtle : isHovered ? Theme.hover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
