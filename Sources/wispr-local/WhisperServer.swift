import Foundation
import WisprLocalCore

/// Keeps whisper loaded in a local helper process, so each transcription skips model loading.
final class WhisperServer {
    private static let requestTimeout: TimeInterval = 30
    private static let startTimeout: TimeInterval = 40
    private static let pollSeconds: TimeInterval = 0.2

    private let model: URL
    private let language: String
    private let lock = NSLock()
    private var process: Process?
    private var keepAlive: Pipe?
    private var port = 0

    init(model: URL, language: String) {
        self.model = model
        self.language = language
    }

    /// Starts the server if it isn't running and waits until it answers. Call off the main thread.
    func ensureRunning() throws {
        try lock.withLock {
            if process?.isRunning == true { return }
            port = Int.random(in: 49_152...65_000)
            // The wrapper kills whisper as soon as our end of the pipe closes, even if we crash.
            let script = "\"$@\" </dev/null >/dev/null 2>&1 & child=$!; (while kill -0 $child 2>/dev/null; do sleep 2; done; kill $$ 2>/dev/null) & cat >/dev/null; kill $child"
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["sh", "-c", script, "sh", Paths.tool("whisper-server"), "-m", model.path,
                                 "--host", "127.0.0.1", "--port", "\(port)", "-l", language, "-nt"]
            process.standardInput = pipe
            try process.run()
            self.process = process
            keepAlive = pipe
            let deadline = Date().addingTimeInterval(Self.startTimeout)
            while Date() < deadline {
                if (try? send(request("/", timeout: 1))) != nil { return }
                guard process.isRunning else { break }
                Thread.sleep(forTimeInterval: Self.pollSeconds)
            }
            try? pipe.fileHandleForWriting.close() // the wrapper then kills whisper
            throw AppError.process("whisper did not start")
        }
    }

    /// Transcribes, restarting whisper once if it died or hung, so a dictation isn't lost.
    func transcribe(_ samples: [Float]) throws -> String {
        do {
            return try attempt(samples)
        } catch {
            log("transcription failed, restarting whisper: \(error)")
            restart()
            return try attempt(samples)
        }
    }

    /// For live words: a failure is ignored, so it can't kill whisper under a real transcription.
    func preview(_ samples: [Float]) throws -> String { try attempt(samples) }

    private func restart() {
        lock.withLock {
            try? keepAlive?.fileHandleForWriting.close()
            keepAlive = nil
            process = nil
        }
    }

    private func attempt(_ samples: [Float]) throws -> String {
        try ensureRunning()
        let boundary = UUID().uuidString
        var body = Data()
        func field(_ name: String, _ value: Data, file: String? = nil) {
            let filename = file.map { "; filename=\"\($0)\"" } ?? ""
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\(filename)\r\n\r\n".utf8))
            body.append(value)
            body.append(Data("\r\n".utf8))
        }
        field("file", WavEncoder.encode(samples), file: "audio.wav")
        field("response_format", Data("text".utf8))
        field("language", Data(language.utf8))
        let words = (try? String(contentsOf: Paths.vocabulary, encoding: .utf8)).map(Vocabulary.prompt) ?? ""
        if !words.isEmpty { field("prompt", Data(words.utf8)) }
        body.append(Data("--\(boundary)--\r\n".utf8))

        var post = request("/inference", timeout: Self.requestTimeout)
        post.httpMethod = "POST"
        post.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        post.httpBody = body
        return Cleanup.normalizeTranscript(String(decoding: try send(post), as: UTF8.self))
    }

    func stop() {
        try? keepAlive?.fileHandleForWriting.close()
        keepAlive = nil
    }

    private func request(_ path: String, timeout: TimeInterval) -> URLRequest {
        URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!, timeoutInterval: timeout)
    }

    private func send(_ request: URLRequest) throws -> Data {
        let done = DispatchSemaphore(value: 0)
        var result: Result<Data, Error> = .failure(AppError.process("no reply from whisper"))
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, http.statusCode == 200, let data {
                result = .success(data)
            }
            done.signal()
        }.resume()
        done.wait()
        return try result.get()
    }
}
