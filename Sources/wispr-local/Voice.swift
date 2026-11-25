import SwiftUI

/// What the microphone is doing right now.
final class LiveVoice: ObservableObject {
    @Published var isRecording = false
    @Published var words = ""
    private(set) var level: Float = 0 // read every frame by the ribbon, so not published

    /// Levels can arrive just after recording stops, so those are dropped.
    func hear(_ level: Float) { if isRecording { self.level = level } }

    func setRecording(_ isOn: Bool) {
        isRecording = isOn
        level = 0
        if isOn { words = "" }
    }
}

/// Soft drifting color with a ribbon that follows the voice. Still when idle in the background or with Reduce Motion.
struct VoiceField: View {
    @ObservedObject var voice: LiveVoice
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.colorScheme) private var scheme
    @State private var smooth = Smoother()

    var body: some View {
        let isPaused = reduceMotion || (activeState == .inactive && !voice.isRecording)
        ZStack {
            // The blurred color is the expensive part and drifts slowly, so it redraws far less often.
            TimelineView(.animation(minimumInterval: 1 / 4, paused: isPaused)) { timeline in
                Canvas { Self.drawAurora($0, $1, time(timeline.date), isDark: scheme == .dark) }
            }
            TimelineView(.animation(minimumInterval: voice.isRecording ? 1 / 30 : 1 / 12, paused: isPaused)) { timeline in
                let level = smooth.next(Double(voice.level))
                Canvas { Self.drawRibbon($0, $1, time(timeline.date), level) }
            }
        }
        .accessibilityHidden(true)
    }

    private func time(_ date: Date) -> Double { reduceMotion ? 0 : date.timeIntervalSinceReferenceDate }

    private static func drawAurora(_ context: GraphicsContext, _ size: CGSize, _ time: Double, isDark: Bool) {
        var context = context
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(isDark ? Color(red: 0.07, green: 0.11, blue: 0.24) : Color(red: 0.15, green: 0.39, blue: 0.84)))
        context.addFilter(.blur(radius: 60))
        let blobs: [(Color, Double, Double, Double, Double)] = [
            (Theme.sky, 0.82, 0.15, 0.62, 0.21), (Theme.mint, 1.0, 0.75, 0.42, 0.17),
            (Theme.lemon, 0.94, 1.15, 0.26, 0.13), (Theme.cobalt, 0.12, 0.2, 0.55, 0.11),
        ]
        for (index, blob) in blobs.enumerated() {
            let (color, x, y, scale, speed) = blob
            let phase = Double(index) * 1.7
            let center = CGPoint(x: size.width * (x + 0.06 * sin(time * speed + phase)), y: size.height * (y + 0.16 * cos(time * speed * 1.3 + phase)))
            let width = size.width * scale, height = size.height * scale * 1.9
            context.fill(Path(ellipseIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)),
                         with: .color(color.opacity(isDark ? 0.55 : 0.9)))
        }
    }

    private static func drawRibbon(_ context: GraphicsContext, _ size: CGSize, _ time: Double, _ level: Double) {
        let lines = 9
        for line in 0..<lines {
            let share = Double(line) / Double(lines - 1)
            let amplitude = size.height * (0.13 + 0.26 * level) * (0.35 + share)
            var path = Path()
            for x in stride(from: 0, through: size.width, by: 4) {
                let place = x / size.width
                let envelope = pow(sin(.pi * place), 2)
                let wave = sin(place * 9 + time * 1.6 + share * 1.2) + 0.5 * sin(place * 17 - time * 2.3 + share * 2)
                let point = CGPoint(x: x, y: size.height * 0.56 + amplitude * envelope * wave * 0.6)
                if x == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(.white.opacity(0.16 + 0.5 * share)), lineWidth: 0.8 + share)
        }
    }

    /// Rises fast and falls slowly, like a meter.
    private final class Smoother {
        private var value = 0.0
        func next(_ target: Double) -> Double {
            value += (target - value) * (target > value ? 0.45 : 0.1)
            return value
        }
    }
}
