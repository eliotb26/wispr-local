/// A modifier key that can be held to talk.
public enum HotKey: String, Sendable {
    case fn
    case rightOption = "right-option"

    public var label: String { self == .fn ? "fn" : "right Option" }

    private var keyCode: UInt16 { self == .fn ? 63 : 61 }

    /// The matching NSEvent.ModifierFlags raw value (.function or .option).
    private var flag: UInt { self == .fn ? 1 << 23 : 1 << 19 }

    /// Whether a flags-changed event pressed (true) or released (false) this key; nil for other keys.
    public func isPressed(keyCode: UInt16, flags: UInt) -> Bool? {
        keyCode == self.keyCode ? flags & flag != 0 : nil
    }
}
