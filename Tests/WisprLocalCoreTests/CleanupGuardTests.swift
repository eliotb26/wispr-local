import Foundation
import Testing
@testable import WisprLocalCore

@Suite("CleanupGuard")
struct CleanupGuardTests {
    @Test("accepts filler, repeat and stutter removal", arguments: [
        ("I I I want to to go to the the store", "I want to go to the store."),
        ("bring the the b-b-budget deck", "Bring the budget deck."),
        ("So um I think we should, we should ship it", "So I think we should ship it."),
        ("and then, like, filters them", "And then filters them."),
        ("it's, uh, the user's fault", "It\u{2019}s the user\u{2019}s fault."),
    ])
    func accepts(raw: String, cleaned: String) {
        #expect(CleanupGuard.isFaithful(cleaned, to: raw))
    }

    @Test("rejects answers, added words and lost sentences", arguments: [
        ("what's the capital of France", "The capital of France is Paris."),
        ("when I don't say anything it registers as thank you, can you fix that?", "When I don't say anything, it registers as thank you."),
        ("can you delete the branch before you deploy", "Delete the branch before you deploy."),
        ("do not send it to Sarah today", "Send it to Sarah today."),
        ("tell Bob to call Alice", "Tell Alice to call Bob."),
        ("ship it on Thursday please", ""),
        ("I like pizza", "I pizza"),
        ("he had had enough", "He had enough"),
        ("it was very very good", "It was very good."),
    ])
    func rejects(raw: String, cleaned: String) {
        #expect(!CleanupGuard.isFaithful(cleaned, to: raw))
    }

    @Test("Claude's edit must be built from the spoken words")
    func plausible() {
        let raw = "can you send me the ticket on Tuesday no wait Thursday"
        #expect(CleanupGuard.isPlausible("Can you send me the ticket on Thursday?", for: raw))
        #expect(!CleanupGuard.isPlausible("Sure! Which ticket would you like me to send?", for: raw))
        #expect(!CleanupGuard.isPlausible("Not logged in. Please run /login", for: raw))
        #expect(!CleanupGuard.isPlausible("", for: raw))
        #expect(!CleanupGuard.isPlausible("I need to make a to-do list.", for: "I need to do a to-do list"))
        #expect(CleanupGuard.isPlausible("Ask Jottey at 3:30.", for: "ask jotty at three thirty"))
    }

    @Test("spots spoken corrections")
    func corrections() {
        #expect(CleanupGuard.hasCorrection("send it Tuesday? No wait, Thursday."))
        #expect(CleanupGuard.hasCorrection("at 3 actually no 4 pm"))
        #expect(!CleanupGuard.hasCorrection("I was waiting on Sarah"))
    }
}

@Suite("WavEncoder")
struct WavEncoderTests {
    @Test("writes a 16 kHz mono header and clamps samples")
    func header() {
        let data = WavEncoder.encode([0, 2, -2])
        #expect(data.count == 44 + 6)
        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "RIFF")
        #expect(data[24] == 0x80 && data[25] == 0x3E)
        #expect(Array(data.suffix(4)) == [0xFF, 0x7F, 0x01, 0x80])
    }
}

@Suite("Vocabulary")
struct VocabularyTests {
    @Test("turns a word list into a prompt, skipping comments")
    func prompt() {
        #expect(Vocabulary.prompt(from: "# names\nJottey\n\n Atrios \n") == "Jottey, Atrios.")
        #expect(Vocabulary.prompt(from: "# none\n") == "")
    }
}
