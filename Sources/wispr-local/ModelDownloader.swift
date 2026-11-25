import CryptoKit
import Foundation

/// Downloads the speech models the first time the app runs and checks they arrived intact.
final class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    struct Model { let name: String; let url: String; let sha256: String }

    static let required = [
        Model(name: Paths.speechModelName, url: "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin",
              sha256: "29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf"),
        Model(name: Paths.modelName, url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin",
              sha256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2"),
    ]

    var onProgress: (Int) -> Void = { _ in }
    var onFinish: (Error?) -> Void = { _ in }
    private var queue: [Model] = []
    private static let retrySeconds: TimeInterval = 5
    /// One at a time and off the main thread, since checking a 574 MB file takes a moment.
    private let callbacks: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let configuration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        return configuration
    }()
    private lazy var session = URLSession(configuration: configuration, delegate: self, delegateQueue: callbacks)

    static var isComplete: Bool { required.allSatisfy { FileManager.default.fileExists(atPath: Paths.model($0.name).path) } }

    func start() {
        queue = Self.required.filter { !FileManager.default.fileExists(atPath: Paths.model($0.name).path) }
        next()
    }

    private func next() {
        guard let model = queue.first, let url = URL(string: model.url) else { return finish(nil) }
        session.downloadTask(with: url).resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let percent = Int(totalBytesWritten * 100 / totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.onProgress(percent) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let model = queue[0]
        do {
            let digest = SHA256.hash(data: try Data(contentsOf: location, options: .mappedIfSafe))
            guard digest.map({ String(format: "%02x", $0) }).joined() == model.sha256 else {
                throw AppError.process("\(model.name) did not download correctly")
            }
            try FileManager.default.createDirectory(at: Paths.models, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: Paths.model(model.name))
            queue.removeFirst()
            next()
        } catch {
            finish(error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error as NSError? else { return }
        log("download interrupted, retrying: \(error.localizedDescription)")
        let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retrySeconds) {
            if let resumeData { self.session.downloadTask(withResumeData: resumeData).resume() } else { self.next() }
        }
    }

    private func finish(_ error: Error?) {
        DispatchQueue.main.async { self.onFinish(error) }
    }
}
