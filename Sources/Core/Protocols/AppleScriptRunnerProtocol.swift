import Foundation

/// Protocol for AppleScript execution.
///
/// Defines the interface for running AppleScript commands. This allows
/// injection of mock implementations for testing without actually executing
/// AppleScript.
///
/// ## Conformance
/// Both real and mock implementations must be actors (or actor-isolated)
/// for safe concurrent use. All implementations must be `Sendable`.
///
/// ## Example
/// ```swift
/// let runner: any AppleScriptRunnerProtocol = AppleScriptRunner.shared
/// let result = try await runner.run(script: "return 2 + 2")
/// print(result) // "4"
/// ```
public protocol AppleScriptRunnerProtocol: Sendable {

    /// Executes an AppleScript and returns the result.
    ///
    /// - Parameter script: The AppleScript code to execute.
    /// - Returns: The string output from the script, or empty string if no output.
    /// - Throws: `AppleScriptError.executionFailed` if the script fails.
    /// - Throws: `CancellationError` if the task is cancelled.
    func run(script: String) async throws -> String

    /// Executes an AppleScript with a timeout.
    ///
    /// - Parameters:
    ///   - script: The AppleScript code to execute.
    ///   - timeout: Maximum time to wait in seconds.
    /// - Returns: The string output from the script.
    /// - Throws: `AppleScriptError.timeout` if the script exceeds the timeout.
    /// - Throws: `AppleScriptError.executionFailed` if the script fails.
    func run(script: String, timeout: TimeInterval) async throws -> String
}
