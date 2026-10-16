import Foundation

/// Command-line options.
public struct Options: Equatable, Sendable {
    public var cleanup = true
    public var language = "en"
    public var showHelp = false

    public init(cleanup: Bool = true, language: String = "en", showHelp: Bool = false) {
        self.cleanup = cleanup
        self.language = language
        self.showHelp = showHelp
    }

    public static let usage = """
    wispr-local: hold right Option, talk, let go. Text lands in the focused field.

    Usage: swift run -c release wispr-local [--raw] [--lang <code>]

      --raw          Skip the Claude cleanup; paste whisper's transcript as-is (fully offline)
      --lang <code>  Spoken language, e.g. en, es, auto (default: en)
      -h, --help     Show this help
    """

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case missingValue(String)
        case unknownFlag(String)

        public var description: String {
            switch self {
            case .missingValue(let flag): return "\(flag) needs a value"
            case .unknownFlag(let flag): return "unknown option \(flag)"
            }
        }
    }

    /// Parses arguments, excluding the program name.
    public static func parse(_ arguments: [String]) throws -> Options {
        var options = Options()
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
            case "-h", "--help":
                options.showHelp = true
            default:
                throw ParseError.unknownFlag(arg)
            }
        }
        return options
    }
}
