import Foundation

/// Command-line options.
public struct Options: Equatable, Sendable {
    public var cleanup = true
    public var language = "en"
    public var showHelp = false
    public var key = HotKey.rightOption
    public var allowClaude = true

    public init(cleanup: Bool = true, language: String = "en", showHelp: Bool = false, key: HotKey = .rightOption) {
        self.cleanup = cleanup
        self.language = language
        self.showHelp = showHelp
        self.key = key
    }

    public static let usage = """
    wispr-local: hold a key, talk, let go. Text lands in the focused field.

    Usage: swift run -c release wispr-local [--raw] [--local] [--lang <code>] [--key <name>]

      --raw          Skip the Claude cleanup; paste whisper's transcript as-is (fully offline)
      --local        Clean up on this Mac only; never call Claude
      --lang <code>  Spoken language, e.g. en, es, auto (default: en)
      --key <name>   Key to hold: fn or right-option (default: right-option; fn in the app)
      -h, --help     Show this help
    """

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case missingValue(String)
        case unknownFlag(String)
        case unknownKey(String)

        public var description: String {
            switch self {
            case .missingValue(let flag): return "\(flag) needs a value"
            case .unknownFlag(let flag): return "unknown option \(flag)"
            case .unknownKey(let key): return "unknown key \(key): use fn or right-option"
            }
        }
    }

    /// Parses arguments, excluding the program name.
    public static func parse(_ arguments: [String], defaultKey: HotKey = .rightOption) throws -> Options {
        var options = Options(key: defaultKey)
        var remaining = arguments[...]
        while let arg = remaining.popFirst() {
            switch arg {
            case "--raw":
                options.cleanup = false
            case "--lang":
                guard let value = remaining.popFirst(), !value.hasPrefix("-") else {
                    throw ParseError.missingValue("--lang")
                }
                options.language = value
            case "--local":
                options.allowClaude = false
            case "--key":
                guard let value = remaining.popFirst(), !value.hasPrefix("-") else {
                    throw ParseError.missingValue("--key")
                }
                guard let key = HotKey(rawValue: value) else { throw ParseError.unknownKey(value) }
                options.key = key
            case "-h", "--help":
                options.showHelp = true
            default:
                throw ParseError.unknownFlag(arg)
            }
        }
        return options
    }
}
