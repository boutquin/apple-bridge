import Foundation

/// Error type for AppleScript execution failures.
public enum AppleScriptError: Error, Sendable {
    case executionFailed(message: String)
    case timeout(seconds: Int)
    case compilationFailed(message: String)

    public var userMessage: String {
        switch self {
        case .executionFailed(let message):
            return "AppleScript execution failed: \(message)"
        case .timeout(let seconds):
            return "AppleScript timeout after \(seconds) seconds"
        case .compilationFailed(let message):
            return "AppleScript compilation failed: \(message)"
        }
    }
}
