import Testing
@testable import WisprLocalCore

@Suite("Disfluency")
struct DisfluencyTests {
    @Test("removes um/uh and repeated phrases, keeps real words", arguments: [
        ("Write a function that, um, sorts users.", "Write a function that sorts users."),
        ("Just tell me a joke. Uh, please.", "Just tell me a joke. Please."),
        ("Um, so I think we should, we should ship it.", "So I think we should ship it."),
        ("It was very very good and he had had enough.", "It was very very good and he had had enough."),
        ("Sort it and then, like, filter it.", "Sort it and then filter it."),
        ("The umbrella is like new.", "The umbrella is like new."),
        ("I spoke to uh Bob, um.", "I spoke to Bob."),
    ])
    func strips(input: String, expected: String) {
        #expect(Disfluency.strip(input) == expected)
    }
}
