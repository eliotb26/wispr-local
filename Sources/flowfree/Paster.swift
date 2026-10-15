import AppKit

/// Pastes text into whatever field has focus, then puts the user's clipboard back.
/// Same approach Wispr's helper uses: concealed pasteboard type so clipboard
/// managers skip it, synthetic Cmd+V, restore shortly after.
enum Paster {
    static let restoreDelay: TimeInterval = 0.5
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let vKeyCode: CGKeyCode = 9

    static func paste(_ text: String) {
        let board = NSPasteboard.general
        let saved = snapshot(board)

        board.clearContents()
        board.setString(text, forType: .string)
        board.setString("", forType: concealedType)

        pressCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            board.clearContents()
            if !saved.isEmpty { board.writeObjects(saved) }
        }
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
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
