import Foundation
import Testing

// MARK: - E2E Test Helper (copied from E2ETests for FDA tests)

/// Runs the apple-bridge executable and captures output.
///
/// This is a minimal copy of E2ETestHelper specifically for FDA degradation tests.
private enum FDATestHelper {
    private static let defaultTimeout: TimeInterval = 5.0
    private static let pollInterval: Duration = .milliseconds(50)

    static let initializeMessage = """
    {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
    """

    static func runAppleBridge(input: String) async throws -> (stdout: String, stderr: String) {
        let executableURL = try findExecutable()

        let process = Process()
        process.executableURL = executableURL

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let inputWithNewlines = input
            .split(separator: "\n", omittingEmptySubsequences: true)
            .joined(separator: "\n") + "\n"

        if let inputData = inputWithNewlines.data(using: .utf8) {
            try stdinPipe.fileHandleForWriting.write(contentsOf: inputData)
        }

        try stdinPipe.fileHandleForWriting.close()

        let startTime = Date()

        while process.isRunning {
            if Date().timeIntervalSince(startTime) > defaultTimeout {
                process.terminate()
                throw FDATestError.timeout
            }
            try await Task.sleep(for: pollInterval)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdout, stderr)
    }

    static func findExecutable() throws -> URL {
        let possiblePaths = [
            ".build/debug/apple-bridge",
            ".build/release/apple-bridge",
            "../../../.build/debug/apple-bridge",
            "../../../.build/release/apple-bridge"
        ]

        if let builtProductsDir = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
            let path = URL(fileURLWithPath: builtProductsDir).appendingPathComponent("apple-bridge")
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        if let buildDir = ProcessInfo.processInfo.environment["BUILD_DIR"] {
            let path = URL(fileURLWithPath: buildDir).appendingPathComponent("apple-bridge")
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        let currentDir = FileManager.default.currentDirectoryPath
        for relativePath in possiblePaths {
            let fullPath = URL(fileURLWithPath: currentDir).appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                return fullPath
            }
        }

        throw FDATestError.executableNotFound
    }
}

private enum FDATestError: Error, CustomStringConvertible {
    case executableNotFound
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

/// Manual QA tests for Full Disk Access (FDA) graceful degradation.
///
/// These tests verify that the apple-bridge server returns helpful error messages
/// when FDA permission is denied. They cannot be automated in CI because they
/// require specific permission states.
///
/// ## Manual QA Checklist
/// 1. Build apple-bridge in release mode: `swift build -c release`
/// 2. Remove FDA permission: System Settings → Privacy & Security → Full Disk Access → uncheck apple-bridge
/// 3. Set environment variables:
///    ```bash
///    export APPLE_BRIDGE_SYSTEM_TESTS=1
///    export APPLE_BRIDGE_MANUAL_QA=1
///    ```
/// 4. Run: `swift test --filter testNotesFDADeniedReturnsPermissionError`
/// 5. Verify test passes (error message contains remediation steps)
/// 6. Re-grant FDA permission after testing
@Suite("FDA Graceful Degradation Tests",
       .enabled(if: SystemTestHelper.systemTestsEnabled && SystemTestHelper.manualQAEnabled))
struct FDAGracefulDegradationTests {

    /// Verifies that Notes operations return helpful error when FDA is denied.
    ///
    /// When Full Disk Access is denied, the notes_search tool should return:
    /// - Error code: PERMISSION_DENIED
    /// - Message mentioning "Full Disk Access"
    /// - Remediation instructions mentioning "System Settings"
    ///
    /// ## IMPORTANT: Manual QA Test
    /// This test requires FDA to be DENIED for the apple-bridge binary.
    /// Run only after removing FDA permission in System Settings.
    @Test("Notes FDA denied returns permission error with remediation")
    func testNotesFDADeniedReturnsPermissionError() async throws {
        let (stdout, _) = try await FDATestHelper.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"notes_search","arguments":{"searchText":"test"}}}
        """)

        // Verify error response contains expected elements
        #expect(stdout.contains("PERMISSION_DENIED"),
                "Expected PERMISSION_DENIED error code in response")
        #expect(stdout.contains("Full Disk Access") || stdout.contains("full disk access"),
                "Expected mention of Full Disk Access in error message")
        #expect(stdout.contains("System Settings") || stdout.contains("System Preferences"),
                "Expected remediation instructions in error message")
    }

    /// Verifies that Messages operations return helpful error when FDA is denied.
    ///
    /// Similar to Notes, Messages requires FDA to read the chat.db database.
    @Test("Messages FDA denied returns permission error with remediation")
    func testMessagesFDADeniedReturnsPermissionError() async throws {
        let (stdout, _) = try await FDATestHelper.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"messages_unread","arguments":{}}}
        """)

        // Verify error response contains expected elements
        #expect(stdout.contains("PERMISSION_DENIED"),
                "Expected PERMISSION_DENIED error code in response")
        #expect(stdout.contains("Full Disk Access") || stdout.contains("full disk access"),
                "Expected mention of Full Disk Access in error message")
    }
}
