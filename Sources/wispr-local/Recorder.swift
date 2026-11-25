import AVFoundation
import WisprLocalCore

/// Records the default microphone as 16 kHz mono samples, kept in memory.
final class Recorder {
    static let sampleRate = Double(WavEncoder.sampleRate)
    private static let levelGain: Float = 12

    /// Loudness from 0 to 1, called on the main thread.
    var onLevel: (Float) -> Void = { _ in }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = [] // appended on the audio thread: guarded by lock
    private(set) var startedAt: Date?

    var isRecording: Bool { startedAt != nil }

    func start() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AppError.audio("no usable microphone")
        }
        lock.withLock { samples = [] }
        let ratio = Self.sampleRate / inputFormat.sampleRate
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let chunk = Self.convert(buffer, with: converter, to: outputFormat, ratio: ratio) else { return }
            self.lock.withLock { self.samples.append(contentsOf: chunk) }
            let level = Self.level(chunk)
            DispatchQueue.main.async { self.onLevel(level) }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0) // a leftover tap would crash the next start
            throw error
        }
        startedAt = Date()
    }

    /// Everything heard so far, or just the last `seconds` of it.
    func snapshot(last seconds: Double? = nil) -> [Float] {
        lock.withLock {
            guard let seconds else { return samples }
            return Array(samples.suffix(Int(seconds * Self.sampleRate)))
        }
    }

    /// Stops recording and returns the audio with the seconds captured.
    func stop() -> (samples: [Float], seconds: TimeInterval) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        defer { startedAt = nil }
        return (snapshot(), startedAt.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private static func level(_ chunk: [Float]) -> Float {
        guard !chunk.isEmpty else { return 0 }
        let power = chunk.reduce(0) { $0 + $1 * $1 } / Float(chunk.count)
        return min(1, power.squareRoot() * levelGain)
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                to format: AVAudioFormat, ratio: Double) -> [Float]? {
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
        guard error == nil, let data = output.floatChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(output.frameLength)))
    }
}
