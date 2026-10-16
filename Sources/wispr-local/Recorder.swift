import AVFoundation

/// Records the default microphone to a 16 kHz mono WAV, the format whisper.cpp expects.
final class Recorder {
    static let sampleRate: Double = 16_000

    private let engine = AVAudioEngine()
    private let fileLock = NSLock()
    private var file: AVAudioFile? // written on the audio thread, closed on main: guarded by fileLock
    private(set) var startedAt: Date?

    var isRecording: Bool { startedAt != nil }

    func start(to url: URL) throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AppError.audio("cannot convert from \(inputFormat)")
        }
        let wavSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        let newFile = try AVAudioFile(forWriting: url, settings: wavSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
        fileLock.withLock { file = newFile }

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self,
                  let converted = Self.convert(buffer, with: converter, to: outputFormat, ratio: ratio) else { return }
            self.fileLock.withLock { try? self.file?.write(from: converted) }
        }
        engine.prepare()
        try engine.start()
        startedAt = Date()
    }

    /// Stops recording, finalises the WAV and returns the seconds captured.
    func stop() -> TimeInterval {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        fileLock.withLock { file = nil } // releasing the file writes the WAV header
        defer { startedAt = nil }
        return startedAt.map { Date().timeIntervalSince($0) } ?? 0
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                to format: AVAudioFormat, ratio: Double) -> AVAudioPCMBuffer? {
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? output : nil
    }
}
