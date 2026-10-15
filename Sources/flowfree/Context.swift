import AppKit
import ApplicationServices

/// What the user is looking at when they start talking: the frontmost app and the
/// text already in the focused field. Wispr sends a much larger version of this
/// (AX words, OCR, editor symbols); this is the minimum that fixes names and tone.
struct ScreenContext {
    let appName: String
    let fieldText: String

    static let maxFieldChars = 1_500

    static func capture() -> ScreenContext {
        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown app"
        return ScreenContext(appName: app, fieldText: focusedFieldText() ?? "")
    }

    private static func focusedFieldText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String else { return nil }
        return String(text.suffix(maxFieldChars))
    }
}
