import Foundation

/// Where models, helper tools and user files live.
enum Paths {
    static let modelName = "ggml-large-v3-turbo-q5_0.bin"
    static let speechModelName = "ggml-silero-v5.1.2.bin"
    /// Set only in the app bundle.
    static let isApp = Bundle.main.bundleIdentifier != nil
    static let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "wispr-local"

    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("wispr-local", isDirectory: true)
    static let voiceTest = support.appendingPathComponent("voice-test", isDirectory: true)
    static let vocabulary = support.appendingPathComponent("words.txt")
    static let totals = support.appendingPathComponent("totals.json")
    static let snippets = support.appendingPathComponent("snippets.json")
    static let notes = support.appendingPathComponent("notes.json")
    static let history = support.appendingPathComponent("history.jsonl")
    static let recordings = support.appendingPathComponent("recordings", isDirectory: true)
    static let log = support.appendingPathComponent("log.txt")
    static let models = isApp ? support.appendingPathComponent("models", isDirectory: true)
        : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("models", isDirectory: true)
    static let runs = isApp ? support.appendingPathComponent("runs.csv")
        : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("runs.csv")

    static func model(_ name: String) -> URL { models.appendingPathComponent(name) }

    /// A helper shipped inside the app, or the same tool from PATH.
    static func tool(_ name: String) -> String {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(name)").path
        return FileManager.default.isExecutableFile(atPath: bundled) ? bundled : name
    }
}

extension Paths {
    /// Apps opened from Finder don't inherit the shell's PATH, so add the usual places tools are installed.
    static func extendSearchPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let nodeVersions = home + "/.nvm/versions/node"
        let newestNode = ((try? FileManager.default.contentsOfDirectory(atPath: nodeVersions)) ?? [])
            .sorted { $0.compare($1, options: .numeric) == .orderedDescending }
            .map { "\(nodeVersions)/\($0)/bin" }
        let folders = [home + "/.local/bin", home + "/.claude/local"] + newestNode + ["/opt/homebrew/bin", "/usr/local/bin"]
        let current = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        setenv("PATH", ([current] + folders).joined(separator: ":"), 1)
    }
}
