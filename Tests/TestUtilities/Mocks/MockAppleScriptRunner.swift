import Foundation
import Core

/// Mock implementation of `AppleScriptRunnerProtocol` for testing.
///
/// Allows tests to verify AppleScript commands without actually executing them.
/// Tracks all executed scripts and can return stub responses or throw errors.
///
/// ## Example
/// ```swift
/// let runner = MockAppleScriptRunner()
/// await runner.setStubResponse("expected output")
/// let service = MailAppleScriptService(runner: runner)
///
/// _ = try await service.unread(limit: 10, includeBody: false)
///
/// let lastScript = await runner.getLastScript()
/// #expect(lastScript?.contains("Mail") == true)
/// ```
public actor MockAppleScriptRunner: AppleScriptRunnerProtocol {

    /// The last script that was executed.
    private var lastScript: String?

    /// All scripts that have been executed, in order.
    private var executedScripts: [String] = []

    /// The response to return from `run(script:)`.
    private var stubResponse: String = ""

    /// Error to throw on `run(script:)` calls, if set.
    private var errorToThrow: (any Error)?

    /// Creates a new mock runner.
    public init() {}

    // MARK: - Test Setup

    /// Sets the response to return from `run(script:)`.
    public func setStubResponse(_ response: String) {
        self.stubResponse = response
    }

    /// Sets an error to throw on subsequent calls.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    /// Clears all recorded scripts.
    public func clearExecutedScripts() {
        self.executedScripts = []
        self.lastScript = nil
    }

    // MARK: - Test Verification

    /// Gets the last script that was executed.
    public func getLastScript() -> String? {
        return lastScript
    }

    /// Gets all scripts that have been executed.
    public func getExecutedScripts() -> [String] {
        return executedScripts
    }

    // MARK: - AppleScriptRunnerProtocol

    public func run(script: String) async throws -> String {
        lastScript = script
        executedScripts.append(script)

        if let error = errorToThrow {
            throw error
        }

        return stubResponse
    }

    public func run(script: String, timeout: TimeInterval) async throws -> String {
        // For the mock, we just delegate to the simple run
        return try await run(script: script)
    }
}
