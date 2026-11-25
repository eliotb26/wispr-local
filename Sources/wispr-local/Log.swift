import Foundation

/// Messages about what went wrong. Never holds dictated text.
func log(_ message: String) {
    FileHandle.standardError.write(Data("[wispr-local] \(message)\n".utf8))
    if Paths.isApp { LogFile.write(message) }
}

private enum LogFile {
    private static let maxBytes = 500_000
    private static let queue = DispatchQueue(label: "wispr-local.log")

    static func write(_ message: String) {
        let line = Data("\(ISO8601DateFormatter().string(from: Date())) \(message)\n".utf8)
        queue.async {
            let manager = FileManager.default
            let size = (try? manager.attributesOfItem(atPath: Paths.log.path)[.size] as? Int) ?? 0
            if size == 0 || size > maxBytes {
                try? manager.createDirectory(at: Paths.support, withIntermediateDirectories: true)
                manager.createFile(atPath: Paths.log.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }
            guard let handle = try? FileHandle(forWritingTo: Paths.log) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        }
    }
}
