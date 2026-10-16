import AppKit
import ApplicationServices
import WisprLocalCore

extension ScreenContext {
    /// The frontmost app and the text already in its focused field, read through Accessibility.
    static func capture() -> ScreenContext {
        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown app"
        return ScreenContext(appName: app, fieldText: focusedFieldText() ?? "")
    }

    private static func focusedFieldText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }

        var value: CFTypeRef?
        let element = focused as! AXUIElement // type checked above
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
