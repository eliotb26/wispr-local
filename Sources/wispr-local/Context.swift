import AppKit
import ApplicationServices
import Carbon.HIToolbox
import WisprLocalCore

extension ScreenContext {
    /// The frontmost app and the text already in its focused field, read through Accessibility.
    static func capture(includeField: Bool) -> ScreenContext {
        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown app"
        return ScreenContext(appName: app, fieldText: includeField ? focusedFieldText() ?? "" : "")
    }

    private static let messagingTimeout: Float = 0.2

    /// Whether a password is being typed. Those dictations are never saved or sent anywhere.
    static func isSecureField() -> Bool {
        guard !IsSecureEventInputEnabled() else { return true }
        return focusedElement().map(isSecure) ?? false
    }

    private static func focusedFieldText() -> String? {
        guard let element = focusedElement(), !isSecure(element) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func isSecure(_ element: AXUIElement) -> Bool {
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        return subrole as? String == kAXSecureTextFieldSubrole
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, messagingTimeout)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }

        let element = focused as! AXUIElement // type checked above
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }
}
