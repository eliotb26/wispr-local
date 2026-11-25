import Testing
@testable import WisprLocalCore

@Suite("SpeechCheck")
struct SpeechCheckTests {
    @Test("only an explicit zero count means silence", arguments: [
        ("Detected 0 speech segments:", true),
        ("Detected 1 speech segments:\nSpeech segment 0: start = 3.00, end = 64.00", false),
        ("Detected 10 speech segments:", false),
        ("", false),
    ])
    func silence(output: String, expected: Bool) {
        #expect(SpeechCheck.isSilent(output) == expected)
    }
}
