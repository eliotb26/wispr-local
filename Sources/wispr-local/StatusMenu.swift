import AppKit

/// Menu bar icon for the app: status, the window, retry and Quit.
final class StatusMenu: NSObject, NSMenuItemValidation {
    var onOpen: () -> Void = {}
    var onRetry: () -> Void = {}
    var canRetry: () -> Bool = { false }
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    override init() {
        super.init()
        let menu = NSMenu()
        menu.addItem(statusLine)
        menu.addItem(.separator())
        for (title, action) in [("Open \(Paths.appName)", #selector(open)), ("Retry Last Dictation", #selector(retry))] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(Paths.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        setRecording(false)
    }

    func setStatus(_ text: String) { statusLine.title = text }

    func setRecording(_ isRecording: Bool) {
        item.button?.image = NSImage(systemSymbolName: isRecording ? "mic.fill" : "mic", accessibilityDescription: Paths.appName)
        item.button?.contentTintColor = isRecording ? .systemRed : nil
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { menuItem.action != #selector(retry) || canRetry() }

    @objc private func open() { onOpen() }
    @objc private func retry() { onRetry() }
}
