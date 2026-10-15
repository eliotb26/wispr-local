import Foundation

enum FlowError: Error, CustomStringConvertible {
    case audio(String)
    case process(String)

    var description: String {
        switch self {
        case .audio(let m): return "audio: \(m)"
        case .process(let m): return "process: \(m)"
        }
    }
}

/// Runs a command, optionally feeding stdin, and returns trimmed stdout.
/// Kills the process and throws if it outlives `timeout`.
func run(_ args: [String], stdin: String? = nil, cwd: URL? = nil, timeout: TimeInterval) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args
    if let cwd { process.currentDirectoryURL = cwd }

    let out = Pipe(), err = Pipe(), inPipe = Pipe()
    process.standardOutput = out
    process.standardError = err
    process.standardInput = inPipe
    try process.run()
    if let stdin { inPipe.fileHandleForWriting.write(Data(stdin.utf8)) }
    try? inPipe.fileHandleForWriting.close()

    let deadline = DispatchTime.now() + timeout
    let done = DispatchSemaphore(value: 0)
    var stdoutData = Data()
    DispatchQueue.global().async {
        stdoutData = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        done.signal()
    }
    if done.wait(timeout: deadline) == .timedOut {
        process.terminate()
        throw FlowError.process("\(args[0]) timed out after \(Int(timeout))s")
    }
    guard process.terminationStatus == 0 else {
        let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        throw FlowError.process("\(args[0]) exited \(process.terminationStatus): \(msg.prefix(300))")
    }
    return String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}
