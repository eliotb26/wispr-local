import AVFoundation

/// Records the default microphone to a 16 kHz mono WAV, the format whisper.cpp expects.
final class Recorder {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private(set) var startedAt: Date?

    func start(to url: URL) throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outFormat) else {
            throw FlowError.audio("cannot convert from \(inputFormat)")
        }
        let wavSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: wavSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
        self.file = file

        let ratio = outFormat.sampleRate / inputFormat.sampleRate
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }
            var consumed = false
            var error: NSError?
            converter.convert(to: out, error: &error) { _, status in
                if consumed { status.pointee = .noDataNow; return nil }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            if error == nil { try? self?.file?.write(from: out) }
        }
        engine.prepare()
        try engine.start()
        startedAt = Date()
    }

    /// Stops recording and returns the seconds of audio captured.
    func stop() -> TimeInterval {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil // closes and finalises the WAV header
        defer { startedAt = nil }
        return startedAt.map { Date().timeIntervalSince($0) } ?? 0
    }
}
