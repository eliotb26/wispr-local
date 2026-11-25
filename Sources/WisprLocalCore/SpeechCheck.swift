/// Reads whisper-vad-speech-segments output. Whisper invents text such as "Thank you." for silence.
public enum SpeechCheck {
    /// Lenient, so quiet or short speech still counts.
    public static let threshold = "0.3"
    public static let minSpeechMs = "100"

    /// True only when the detector says there was no speech; unclear output counts as speech.
    public static func isSilent(_ output: String) -> Bool {
        output.contains("Detected 0 speech segments")
    }
}
