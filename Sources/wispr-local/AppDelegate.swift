import AppKit

/// Opens the window when the app is launched or clicked again, and gives text fields their shortcuts.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onReopen: () -> Void = {}

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        onReopen()
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // At login, stay in the menu bar.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLogin = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !isLogin { onReopen() }
    }

    static func makeMenu() -> NSMenu {
        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            let holder = NSMenuItem()
            holder.submenu = menu
            return holder
        }
        func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
            NSMenuItem(title: title, action: action, keyEquivalent: key)
        }
        let menu = NSMenu()
        menu.addItem(submenu(Paths.appName, [item("Hide \(Paths.appName)", #selector(NSApplication.hide(_:)), "h"),
                                             item("Quit \(Paths.appName)", #selector(NSApplication.terminate(_:)), "q")]))
        menu.addItem(submenu("Edit", [item("Undo", Selector(("undo:")), "z"), item("Redo", Selector(("redo:")), "Z"), .separator(),
                                      item("Cut", #selector(NSText.cut(_:)), "x"), item("Copy", #selector(NSText.copy(_:)), "c"),
                                      item("Paste", #selector(NSText.paste(_:)), "v"), item("Select All", #selector(NSText.selectAll(_:)), "a")]))
        menu.addItem(submenu("Window", [item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
                                        item("Close", #selector(NSWindow.performClose(_:)), "w")]))
        return menu
    }
}
