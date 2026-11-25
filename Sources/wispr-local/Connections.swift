import AppKit
import SwiftUI
import WisprLocalCore

/// Serves the history and notes to an AI app that started us, over standard input and output.
enum ConnectorServer {
    static let flag = "--mcp"

    static func run() -> Never {
        let connector = Connector(
            history: { Settings.retention.keep(try HistoryFile(url: Paths.history).load().reversed(), now: Date()) },
            notes: { try JSONFile<[Note]>(url: Paths.notes).load() ?? [] })
        while let line = readLine() {
            guard !line.isEmpty, let reply = connector.reply(to: Data(line.utf8)) else { continue }
            FileHandle.standardOutput.write(reply + Data("\n".utf8))
        }
        exit(0)
    }
}

/// An AI app whose settings file can list us.
enum ConnectedApp: String, CaseIterable {
    case claudeCode = "Claude Code", claude = "Claude", cursor = "Cursor"

    private var config: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .claudeCode: return home.appendingPathComponent(".claude.json")
        case .claude: return home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        case .cursor: return home.appendingPathComponent(".cursor/mcp.json")
        }
    }

    var detail: String {
        switch self {
        case .claudeCode: return "In your terminal"
        case .claude: return "The desktop app. Reopen it after connecting."
        case .cursor: return "The code editor"
        }
    }

    var isConnected: Bool { ConnectorConfig.isConnected(try? Data(contentsOf: config)) }

    /// Claude Code rewrites its file while running, so its own command makes the change.
    func setConnected(_ isOn: Bool) throws {
        if self == .claudeCode {
            let command = isOn ? ["claude", "mcp", "add", "--scope", "user", Connector.name, "--"] + Self.launch : ["claude", "mcp", "remove", "--scope", "user", Connector.name]
            _ = try run(command, timeout: 20)
            return
        }
        let file = config.resolvingSymlinksInPath()
        let exists = FileManager.default.fileExists(atPath: file.path)
        let before = exists ? try Data(contentsOf: file) : nil
        let after = try isOn ? ConnectorConfig.connecting(before, command: Self.launch[0], arguments: Array(Self.launch.dropFirst()))
            : ConnectorConfig.disconnecting(before)
        guard FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path) else { throw AppError.process("not installed") }
        let mode = exists ? try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] : 0o600
        let backup = file.appendingPathExtension("chirpkey-backup")
        if let before, !FileManager.default.fileExists(atPath: backup.path) { // the first one is the true original
            guard FileManager.default.createFile(atPath: backup.path, contents: before, attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
        }
        try after.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: mode ?? 0o600], ofItemAtPath: file.path)
    }

    private static let launch = [Bundle.main.executablePath ?? "wispr-local", ConnectorServer.flag]
    static var copyable: String {
        let data = try? ConnectorConfig.connecting(nil, command: launch[0], arguments: Array(launch.dropFirst()))
        return data.map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}

struct ConnectionsPane: View {
    @State private var useClaude = Settings.useClaude
    @State private var connected: Set<ConnectedApp> = []
    @State private var busy: ConnectedApp?
    @State private var asking: ConnectedApp?
    @State private var problem: String?
    @State private var isCopied = false

    var body: some View {
        Pane(title: "Connections", subtitle: "Let AI apps on this Mac search your dictations and notes. They can read, never change.") {
            Card {
                ForEach(ConnectedApp.allCases, id: \.self) { app in
                    GraphiteRow(title: app.rawValue, detail: app.detail) {
                        if connected.contains(app) {
                            Label("Connected", systemImage: "checkmark").font(Theme.smallMedium).foregroundStyle(Theme.success)
                            Button("Remove") { change(app, false) }.graphite(.ghost, small: true).disabled(busy != nil)
                        } else {
                            Button(busy == app ? "Connecting\u{2026}" : "Connect") { asking = app }.graphite().disabled(busy != nil)
                        }
                    }
                }
                GraphiteRow(title: "Any other app", detail: "Paste this into its MCP settings.", isLast: true) {
                    Button(isCopied ? "Copied" : "Copy setup") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(ConnectedApp.copyable, forType: .string)
                        isCopied = true
                    }
                    .graphite()
                }
            }
            if let problem { Text(problem).font(Theme.small).foregroundStyle(Theme.danger).padding(.top, 12) }
            SectionLabel("Writing help")
            Card {
                GraphiteRow(title: "Use Claude for hard edits", detail: "Sends those transcripts, the app's name and nearby text to Claude.", isLast: true) {
                    Toggle("", isOn: $useClaude).labelsHidden().toggleStyle(.switch).controlSize(.small).onChange(of: useClaude) { Settings.useClaude = $0 }
                        .accessibilityLabel("Use Claude for hard edits")
                }
            }
        }
        .onAppear(perform: refresh)
        .confirmationDialog("Let \(asking?.rawValue ?? "") read your dictations?", isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }), presenting: asking) { app in
            Button("Connect") { change(app, true) }
        } message: { _ in Text("What it reads may be sent to the company that runs it.") }
    }

    private func change(_ app: ConnectedApp, _ isOn: Bool) {
        busy = app
        problem = nil
        DispatchQueue.global().async {
            let result = Result { try app.setConnected(isOn) }
            DispatchQueue.main.async {
                busy = nil
                if case .failure(let error) = result {
                    log("connection: \(type(of: error))")
                    problem = error is ConnectorConfig.Unreadable ? "\(app.rawValue)'s settings file couldn't be read, so nothing was changed." : "Couldn't change \(app.rawValue). Is it installed?"
                }
                refresh()
            }
        }
    }

    private func refresh() { connected = Set(ConnectedApp.allCases.filter(\.isConnected)) }
}
