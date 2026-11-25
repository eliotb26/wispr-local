import Foundation
import ServiceManagement
import WisprLocalCore

/// The user's choices, saved in preferences.
enum Settings {
    private static let defaults = UserDefaults.standard

    /// Off by default: turning it on sends some transcripts and field text to Claude.
    static var useClaude: Bool {
        get { defaults.bool(forKey: "useClaude") }
        set { defaults.set(newValue, forKey: "useClaude") }
    }

    static var retention: Retention {
        get { defaults.string(forKey: "retention").flatMap(Retention.init) ?? .month }
        set { defaults.set(newValue.rawValue, forKey: "retention") }
    }

    /// Off by default. Recordings are for measuring and training on the user's own voice.
    static var keepAudio: Bool {
        get { defaults.bool(forKey: "keepAudio") }
        set { defaults.set(newValue, forKey: "keepAudio") }
    }

    static var playSound: Bool {
        get { defaults.object(forKey: "playSound") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "playSound") }
    }

    /// The key chosen in Settings, if any.
    static var key: HotKey? {
        get { defaults.string(forKey: "key").flatMap(HotKey.init) }
        set { defaults.set(newValue?.rawValue, forKey: "key") }
    }

    static var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    static func setOpensAtLogin(_ isOn: Bool) throws {
        if isOn { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
