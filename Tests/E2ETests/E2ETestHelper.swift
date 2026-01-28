import Foundation
import TestUtilities

/// Shared test helper for E2E tests.
///
/// Provides utilities for running the apple-bridge executable and capturing output.
/// This is a thin wrapper around `ProcessRunner` from TestUtilities, maintaining
/// the original API for backward compatibility.
///
/// ## Migration Note
/// This helper now delegates to `ProcessRunner` from the shared TestUtilities module.
/// New tests should use `ProcessRunner` directly for better discoverability.
enum E2ETestHelper {

    /// Standard initialize message for MCP protocol handshake.
    ///
    /// Use this constant to avoid duplicating the JSON-RPC initialize message
    /// across multiple tests.
    static let initializeMessage = ProcessRunner.initializeMessage

    /// Runs the apple-bridge executable with the given input and returns stdout/stderr.
    ///
    /// This method delegates to `ProcessRunner.runAppleBridge(input:)`.
    ///
    /// - Parameter input: The JSON-RPC messages to send to stdin (newline-delimited)
    /// - Returns: A tuple of (stdout, stderr) output strings
    /// - Throws: `E2EError.executableNotFound` if the executable cannot be located,
    ///           `E2EError.timeout` if the process doesn't complete within the timeout
    static func runAppleBridge(input: String) async throws -> (stdout: String, stderr: String) {
        do {
            return try await ProcessRunner.runAppleBridge(input: input)
        } catch let error as ProcessRunnerError {
            // Map ProcessRunnerError to E2EError for backward compatibility
            switch error {
            case .executableNotFound:
                throw E2EError.executableNotFound
            case .timeout:
                throw E2EError.timeout
            }
        }
    }

    /// Finds the apple-bridge executable in the build directory.
    ///
    /// This method delegates to `ProcessRunner.findExecutable()`.
    ///
    /// - Returns: The URL to the executable
    /// - Throws: `E2EError.executableNotFound` if the executable cannot be located
    static func findExecutable() throws -> URL {
        do {
            return try ProcessRunner.findExecutable()
        } catch {
            throw E2EError.executableNotFound
        }
    }
}

/// Errors that can occur during E2E testing.
///
/// These errors indicate infrastructure problems with running the E2E tests,
/// not failures in the code being tested.
enum E2EError: Error, Sendable, CustomStringConvertible {
    /// The apple-bridge executable could not be found.
    ///
    /// This typically means the project hasn't been built yet.
    /// Run `swift build` to create the executable.
    case executableNotFound

    /// The process did not complete within the allowed time.
    ///
    /// This may indicate the server is hanging or there's a deadlock.
    case timeout

    var description: String {
        switch self {
        case .executableNotFound:
            return "Could not find apple-bridge executable. Run 'swift build' first."
        case .timeout:
            return "Process timed out waiting for response"
        }
    }
}
