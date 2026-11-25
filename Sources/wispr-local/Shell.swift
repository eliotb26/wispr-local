import Foundation

enum AppError: Error, CustomStringConvertible {
    case audio(String)
    case process(String)

    var description: String {
        switch self {
        case .audio(let message): return "audio: \(message)"
        case .process(let message): return "process: \(message)"
        }
    }
}

/// Runs a command found on PATH, optionally feeding stdin, and returns trimmed stdout.
/// Kills the process and throws if it outlives `timeout`.
func run(_ arguments: [String], stdin: String? = nil, cwd: URL? = nil, timeout: TimeInterval) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    if let cwd { process.currentDirectoryURL = cwd }

    let stdoutPipe = Pipe(), stderrPipe = Pipe(), stdinPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.standardInput = stdinPipe
    try process.run()

    // Drain both pipes concurrently so a chatty process can't fill one and block.
    let group = DispatchGroup()
    var stdoutData = Data(), stderrData = Data()
    DispatchQueue.global().async(group: group) { stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile() }
    DispatchQueue.global().async(group: group) { stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile() }

    if let stdin { try? stdinPipe.fileHandleForWriting.write(contentsOf: Data(stdin.utf8)) } // a failed child is reported below
    try? stdinPipe.fileHandleForWriting.close()

    guard group.wait(timeout: .now() + timeout) == .success else {
        process.terminate()
        throw AppError.process("\(arguments[0]) timed out after \(Int(timeout))s")
    }
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        // The tool's own message could quote the dictation, and errors are logged, so leave it out.
        throw AppError.process("\(arguments[0]) exited \(process.terminationStatus) (\(stderrData.count) bytes of errors)")
    }
    return String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}
