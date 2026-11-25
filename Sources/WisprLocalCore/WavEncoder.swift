import Foundation

/// Encodes 16 kHz mono float samples as a 16-bit WAV, the format whisper.cpp expects.
public enum WavEncoder {
    public static let sampleRate: UInt32 = 16_000

    public static func encode(_ samples: [Float]) -> Data {
        let byteCount = UInt32(samples.count * 2)
        var data = Data(capacity: 44 + samples.count * 2)
        func put<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); put(36 + byteCount)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); put(UInt32(16)); put(UInt16(1)); put(UInt16(1))
        put(sampleRate); put(sampleRate * 2); put(UInt16(2)); put(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); put(byteCount)
        for sample in samples { put(Int16(max(-1, min(1, sample)) * 32_767)) }
        return data
    }
}

/// The user's own names and terms, one per line; "#" starts a comment.
public enum Vocabulary {
    public static func prompt(from text: String) -> String {
        let terms = terms(in: text)
        return terms.isEmpty ? "" : terms.joined(separator: ", ") + "."
    }
}
