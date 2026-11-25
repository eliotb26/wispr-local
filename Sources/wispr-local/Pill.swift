import AppKit
import SwiftUI

/// What the pill shows.
enum PillState: Equatable {
    case listening, working, error(String)
}

final class PillModel: ObservableObject {
    static let barCount = 14
    @Published var state = PillState.listening
    @Published var words = ""
    @Published var levels = [Float](repeating: 0, count: PillModel.barCount)
}

/// A small capsule at the bottom of the screen. It never takes focus or clicks.
final class Pill {
    private static let size = NSSize(width: 520, height: 64)
    private static let bottomMargin: CGFloat = 24
    private static let errorSeconds: TimeInterval = 3

    private let model = PillModel()
    private let panel: NSPanel
    private var hideTimer: Timer?

    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: PillView(model: model))
    }

    func listening() {
        model.words = ""
        model.levels = [Float](repeating: 0, count: PillModel.barCount)
        show(.listening)
    }

    func working() { show(.working) }

    func error(_ message: String) {
        show(.error(message))
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.errorSeconds, repeats: false) { [weak self] _ in self?.hide() }
    }

    func hide() {
        hideTimer?.invalidate()
        panel.orderOut(nil)
    }

    func setLevel(_ level: Float) { model.levels = model.levels.dropFirst() + [level] }

    func setWords(_ words: String) { model.words = words }

    private func show(_ state: PillState) {
        hideTimer?.invalidate()
        model.state = state
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - Self.size.width / 2, y: frame.minY + Self.bottomMargin))
        }
        panel.orderFrontRegardless()
    }
}

private struct PillView: View {
    private static let maxCaptionWidth: CGFloat = 400
    @ObservedObject var model: PillModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            switch model.state {
            case .listening:
                bars
                if !model.words.isEmpty { caption(model.words) }
            case .working:
                ProgressView().controlSize(.small)
                caption(model.words.isEmpty ? "Working\u{2026}" : model.words).opacity(0.6)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning)
                caption(message)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(Capsule().fill(Color(red: 0.051, green: 0.055, blue: 0.063)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bars: some View {
        HStack(spacing: 2.5) {
            ForEach(model.levels.indices, id: \.self) { index in
                Capsule().fill(Theme.accent).frame(width: 2.5, height: 20)
                    .scaleEffect(y: CGFloat(max(0.14, model.levels[index])))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: model.levels)
    }

    private func caption(_ text: String) -> some View {
        let font = NSFont(name: "Geist-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        let width = (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
        return Text(text).font(Font(font)).foregroundStyle(.white)
            .lineLimit(1).truncationMode(.head).frame(width: min(width, Self.maxCaptionWidth))
    }
}
