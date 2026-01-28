import Foundation
import Core

/// Actor for executing AppleScript commands.
///
/// `AppleScriptRunner` serializes all AppleScript executions to prevent
/// race conditions when multiple tools attempt to use AppleScript simultaneously.
/// This is important because some AppleScript operations (like sending messages)
/// require exclusive access to the target application.
///
/// ## Usage
/// ```swift
/// let runner = AppleScriptRunner.shared
/// let result = try await runner.run(script: "return 2 + 2")
/// print(result) // "4"
/// ```
///
/// ## Thread Safety
/// As an actor, all method calls are automatically serialized.
/// Concurrent calls will queue and execute one at a time.
public actor AppleScriptRunner: AppleScriptRunnerProtocol {

    /// Shared singleton instance.
    ///
    /// Use this for all AppleScript execution to ensure proper serialization.
    public static let shared = AppleScriptRunner()

    /// Private initializer to enforce singleton pattern.
    private init() {}

    /// Executes an AppleScript and returns the result.
    ///
    /// - Parameter script: The AppleScript code to execute.
    /// - Returns: The string output from the script, or empty string if no output.
    /// - Throws: `AppleScriptError.executionFailed` if the script fails.
    /// - Throws: `CancellationError` if the task is cancelled.
    ///
    /// ## Example
    /// ```swift
    /// let result = try await AppleScriptRunner.shared.run(script: """
    ///     tell application "Messages"
    ///         activate
    ///     end tell
    ///     """)
    /// ```
    public func run(script: String) async throws -> String {
        // Check for cancellation before starting
        try Task.checkCancellation()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw AppleScriptError.executionFailed(message: "Failed to start osascript: \(error.localizedDescription)")
        }

        // Use withTaskCancellationHandler to terminate process if task is cancelled
        return try await withTaskCancellationHandler {
            // Wait for completion
            process.waitUntilExit()

            // Check for cancellation after execution
            try Task.checkCancellation()

            // Check exit status
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "Unknown AppleScript error"
                throw AppleScriptError.executionFailed(message: errorMessage)
            }

            // Read output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return output
        } onCancel: {
            // Terminate the process if the task is cancelled
            if process.isRunning {
                process.terminate()
            }
        }
    }

    /// Executes an AppleScript with a timeout.
    ///
    /// - Parameters:
    ///   - script: The AppleScript code to execute.
    ///   - timeout: Maximum time to wait in seconds.
    /// - Returns: The string output from the script.
    /// - Throws: `AppleScriptError.timeout` if the script exceeds the timeout.
    /// - Throws: `AppleScriptError.executionFailed` if the script fails.
    public func run(script: String, timeout: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.run(script: script)
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw AppleScriptError.timeout(seconds: Int(timeout))
            }

            guard let result = try await group.next() else {
                throw AppleScriptError.executionFailed(message: "No result from AppleScript execution")
            }

            group.cancelAll()
            return result
        }
    }
}
