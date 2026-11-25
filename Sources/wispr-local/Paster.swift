import AppKit

/// Pastes text into whatever field has focus, then puts the user's clipboard back.
/// The text is marked concealed so clipboard managers don't record it.
enum Paster {
    static let restoreDelay: TimeInterval = 0.5
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    /// Marks our own key presses, so they aren't taken for the user's.
    private static let eventMark: Int64 = 0x57_4C_4F_43
    private static let vKeyCode: CGKeyCode = 9

    static func paste(_ text: String) {
        let board = NSPasteboard.general
        let saved = snapshot(board)

        board.clearContents()
        board.setString(text, forType: .string)
        board.setString("", forType: concealedType)
        let ourChange = board.changeCount

        pressCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            // If the user copied something in the meantime, keep theirs.
            guard board.changeCount == ourChange else { return }
            board.clearContents()
            if !saved.isEmpty { board.writeObjects(saved) }
        }
    }

    static func isOurs(_ event: NSEvent) -> Bool {
        event.cgEvent?.getIntegerValueField(.eventSourceUserData) == eventMark
    }

    private static func snapshot(_ board: NSPasteboard) -> [NSPasteboardItem] {
        (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isKeyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: isKeyDown)
            event?.flags = .maskCommand
            event?.setIntegerValueField(.eventSourceUserData, value: eventMark)
            event?.post(tap: .cghidEventTap)
        }
    }
}
