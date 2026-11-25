import Testing
@testable import WisprLocalCore

@Suite("HotKey")
struct HotKeyTests {
    @Test("--key overrides the default")
    func parsesKey() throws {
        #expect(try Options.parse(["--key", "fn"]).key == .fn)
        #expect(try Options.parse([]).key == .rightOption)
        #expect(try Options.parse([], defaultKey: .fn).key == .fn)
        #expect(throws: Options.ParseError.unknownKey("tab")) { try Options.parse(["--key", "tab"]) }
        #expect(throws: Options.ParseError.missingValue("--key")) { try Options.parse(["--key"]) }
    }

    @Test("--local turns Claude off")
    func local() throws {
        #expect(try Options.parse([]).allowClaude)
        #expect(try !Options.parse(["--local"]).allowClaude)
    }

    @Test("reports press and release of its own key only")
    func pressState() {
        #expect(HotKey.fn.isPressed(keyCode: 63, flags: 1 << 23) == true)
        #expect(HotKey.fn.isPressed(keyCode: 63, flags: 0) == false)
        #expect(HotKey.fn.isPressed(keyCode: 61, flags: 1 << 19) == nil)
        #expect(HotKey.rightOption.isPressed(keyCode: 61, flags: 1 << 19) == true)
    }
}
