import SwiftUI
import WisprLocalCore

/// Reads sentences aloud, one at a time, and saves each recording next to its text for scripts/voice-eval.py.
final class VoiceTest: ObservableObject {
    static let sentences = [
        "Can you send me the latest draft before lunch?", "I think we should ship the fix on Thursday.",
        "Let's move the meeting to three thirty on Friday.", "The numbers in the pricing page look wrong.",
        "Thanks for the quick reply, I really appreciate it.", "Please review my pull request when you get a chance.",
        "The build failed because the test database was empty.", "Add a filter so people can search by company.",
        "What would it take to make this work offline?", "I'll follow up with Sarah and Brian tomorrow morning.",
        "We need a stronger opening line for the newsletter.", "Rewrite this paragraph so it sounds more like me.",
        "The customer asked about security and data storage.", "Schedule a call with the product team next week.",
        "Show me every account that hasn't replied in thirty days.", "Split this function into smaller pieces and add tests.",
        "Our revenue grew twenty percent compared with last year.", "Could you explain why the first version was slower?",
        "Remember to update the design system before we launch.", "Three things matter most: speed, quality and trust.",
        "I'd rather start small and improve it every week.", "Please book a train to Boston for Wednesday evening.",
        "The research paper compares several robot learning methods.", "Make the button bigger and move it to the right.",
        "She said the proposal was clear but a little too long.", "Does the application still work without an internet connection?",
        "Create a spreadsheet with names, titles and email addresses.", "My biggest question is whether people will pay for this.",
        "Stop the server, clear the cache and try again.", "Great work, let's talk about the next step on Monday.",
    ]

    @Published var index = 0
    @Published var status = ""
    var isDone: Bool { index >= Self.sentences.count }

    func open() {
        do {
            try FileManager.default.createDirectory(at: Paths.voiceTest, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: Paths.voiceTest.path)
        } catch {
            status = "Couldn't make the folder: \(error.localizedDescription)"
        }
        index = Self.sentences.indices.first { !FileManager.default.fileExists(atPath: file($0, "wav").path) } ?? Self.sentences.count
    }

    func save(_ samples: [Float]) {
        guard index < Self.sentences.count else { return }
        do {
            try WavEncoder.encode(samples).write(to: file(index, "wav"))
            try Data(Self.sentences[index].utf8).write(to: file(index, "txt"))
            status = ""
            index += 1
        } catch {
            status = "Couldn't save: \(error.localizedDescription)"
        }
    }

    func back() { if index > 0 { index -= 1 } }

    private func file(_ index: Int, _ ext: String) -> URL {
        Paths.voiceTest.appendingPathComponent(String(format: "%02d.%@", index + 1, ext))
    }
}

struct VoiceTestView: View {
    @ObservedObject var test: VoiceTest
    @ObservedObject var voice: LiveVoice
    let keyLabel: String

    var body: some View {
        Page(title: "Voice test", subtitle: "Read 30 sentences to measure how well each speech model hears you.") {
            VStack(alignment: .leading, spacing: 24) {
                progress
                Text(test.isDone ? "All \(VoiceTest.sentences.count) sentences recorded" : VoiceTest.sentences[test.index])
                    .font(Theme.display).tracking(-0.8).fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 80, alignment: .topLeading)
                Text(hint).font(Theme.reading).foregroundStyle(test.status.isEmpty ? Theme.muted : Theme.danger)
                VoiceField(voice: voice).frame(height: 112).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                HStack(spacing: 8) {
                    Button("Redo previous") { test.back() }.graphite().disabled(test.index == 0)
                    Button("Show recordings") { NSWorkspace.shared.open(Paths.voiceTest) }.graphite(.ghost)
                }
            }
        }
        .onAppear(perform: test.open)
    }

    private var hint: String {
        if !test.status.isEmpty { return test.status }
        return test.isDone ? "They stay on this Mac." : "Hold \(keyLabel), read it the way you normally talk, then let go."
    }

    private var progress: some View {
        let count = VoiceTest.sentences.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { Capsule().fill($0 < test.index ? Theme.control : Theme.border).frame(height: 4) }
            }
            Text("\(min(test.index + 1, count)) of \(count)").font(Theme.small).foregroundStyle(Theme.muted).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
