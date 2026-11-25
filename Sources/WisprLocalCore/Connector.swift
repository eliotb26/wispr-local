import Foundation

/// Answers Model Context Protocol requests from AI apps on this Mac. Read only.
public struct Connector {
    public static let name = "chirpkey"
    public static let defaultLimit = 20, maxLimit = 100
    static let protocols = ["2025-06-18", "2025-03-26", "2024-11-05"]

    private let history: () throws -> [Dictation] // newest first
    private let notes: () throws -> [Note]

    public init(history: @escaping () throws -> [Dictation], notes: @escaping () throws -> [Note]) {
        self.history = history
        self.notes = notes
    }

    /// The reply to one line of input, or nil for notifications.
    public func reply(to line: Data) -> Data? {
        guard let request = try? JSONSerialization.jsonObject(with: line) as? [String: Any], let method = request["method"] as? String else {
            return encode(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Parse error"]])
        }
        guard let id = request["id"] else { return nil }
        let params = request["params"] as? [String: Any] ?? [:]
        switch method {
        case "initialize":
            let asked = params["protocolVersion"] as? String ?? ""
            return result(id, ["protocolVersion": Self.protocols.contains(asked) ? asked : Self.protocols[0], "capabilities": ["tools": [String: Any]()],
                               "serverInfo": ["name": Self.name, "version": "1.0"]])
        case "ping": return result(id, [:])
        case "tools/list": return result(id, ["tools": Self.tools])
        case "tools/call": return call(id, params)
        default: return encode(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Unknown method"]])
        }
    }

    private static let tools: [[String: Any]] = [
        tool("search_dictations", "Search the user's past dictations, newest first. Leave query empty for the latest."),
        tool("search_notes", "Search the user's scratchpad notes. Leave query empty for all."),
    ]

    private static func tool(_ name: String, _ description: String) -> [String: Any] {
        ["name": name, "description": description, "annotations": ["readOnlyHint": true],
         "inputSchema": ["type": "object", "properties": ["query": ["type": "string"], "limit": ["type": "integer", "minimum": 1, "maximum": maxLimit]]]]
    }

    private func call(_ id: Any, _ params: [String: Any]) -> Data {
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        let query = (arguments["query"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let limit = min(Self.maxLimit, max(1, arguments["limit"] as? Int ?? Self.defaultLimit))
        let stamp = ISO8601DateFormatter()
        do {
            switch params["name"] as? String {
            case "search_dictations":
                let found = try history().filter { $0.outcome == .typed && $0.matches(query) }.prefix(limit)
                return text(id, found.map { "[\(stamp.string(from: $0.date))] \($0.app): \($0.finalText)" }, none: "No dictations found.")
            case "search_notes":
                let found = try notes().filter { !$0.text.isEmpty && (query.isEmpty || $0.text.localizedCaseInsensitiveContains(query)) }.prefix(limit)
                return text(id, found.map { "[\(stamp.string(from: $0.date))]\n\($0.text)" }, none: "No notes found.")
            default: return encode(["jsonrpc": "2.0", "id": id, "error": ["code": -32602, "message": "Unknown tool"]])
            }
        } catch {
            return result(id, ["content": [["type": "text", "text": "Couldn't read the saved data."]], "isError": true])
        }
    }

    private func text(_ id: Any, _ lines: [String], none: String) -> Data {
        result(id, ["content": [["type": "text", "text": lines.isEmpty ? none : lines.joined(separator: "\n\n")]]])
    }

    private func result(_ id: Any, _ value: [String: Any]) -> Data { encode(["jsonrpc": "2.0", "id": id, "result": value]) }

    private func encode(_ value: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
    }
}

/// Edits another app's MCP settings file without touching anything else in it.
public enum ConnectorConfig {
    public struct Unreadable: Error {}
    private static let key = "mcpServers"

    public static func isConnected(_ data: Data?) -> Bool {
        guard let data, let servers = try? object(data)[key] as? [String: Any] else { return false }
        return servers[Connector.name] != nil
    }

    public static func connecting(_ data: Data?, command: String, arguments: [String]) throws -> Data {
        try changing(data) { $0.merging([Connector.name: ["command": command, "args": arguments]]) { $1 } }
    }

    public static func disconnecting(_ data: Data?) throws -> Data {
        try changing(data) { $0.filter { $0.key != Connector.name } }
    }

    private static func changing(_ data: Data?, _ change: ([String: Any]) -> [String: Any]) throws -> Data {
        let root = try object(data)
        if let existing = root[key], !(existing is [String: Any]) { throw Unreadable() }
        let updated = root.merging([key: change(root[key] as? [String: Any] ?? [:])]) { $1 }
        return try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    private static func object(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Unreadable() }
        return root
    }
}
