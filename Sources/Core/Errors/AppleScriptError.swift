import Foundation

/// Errors from AppleScript execution.
///
/// These errors occur when running AppleScript to control Apple applications
/// (e.g., Notes, Maps) that don't have direct API access.
///
/// ## Common Causes
/// - `executionFailed`: The script ran but the target app returned an error
/// - `timeout`: The script took too long (app may be unresponsive)
/// - `compilationFailed`: The script has syntax errors
///
/// ## Example
/// ```swift
/// do {
///     let notes = try await notesAdapter.listNotes()
/// } catch let error as AppleScriptError {
///     print(error.userMessage)
/// }
/// ```
public enum AppleScriptError: Error, Sendable {
    /// The script executed but failed with an error from the target application.
    case executionFailed(message: String)

    /// The script execution exceeded the timeout period.
    case timeout(seconds: Int)

    /// The script failed to compile (syntax error).
    case compilationFailed(message: String)

    /// A user-friendly message describing the error.
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
