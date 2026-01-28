import Foundation
import Testing

/// End-to-end tests for the apple-bridge MCP server.
///
/// These tests verify that the server correctly handles MCP protocol messages
/// by starting the actual executable and communicating via stdin/stdout.
@Suite("E2E Tests")
struct E2ETests {

    // MARK: - Test Helper

    /// Runs the apple-bridge executable with the given input and returns stdout/stderr.
    ///
    /// - Parameter input: The JSON-RPC messages to send to stdin (newline-delimited)
    /// - Returns: A tuple of (stdout, stderr) output strings
    /// - Throws: If the process fails to start or times out
    private func runAppleBridge(input: String) async throws -> (stdout: String, stderr: String) {
        // Find the built executable
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

        // Write input to stdin, adding newlines between messages
        let inputWithNewlines = input
            .split(separator: "\n", omittingEmptySubsequences: true)
            .joined(separator: "\n") + "\n"

        if let inputData = inputWithNewlines.data(using: .utf8) {
            try stdinPipe.fileHandleForWriting.write(contentsOf: inputData)
        }

        // Close stdin to signal EOF
        try stdinPipe.fileHandleForWriting.close()

        // Wait for output with timeout
        let startTime = Date()
        let timeout: TimeInterval = 5.0

        while process.isRunning {
            if Date().timeIntervalSince(startTime) > timeout {
                process.terminate()
                throw E2ETestError.timeout
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        // Read all output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdout, stderr)
    }

    /// Finds the apple-bridge executable in the build directory.
    private func findExecutable() throws -> URL {
        // When running tests, the executable should be in the same directory as the test bundle
        // or we can find it relative to the package
        let possiblePaths = [
            // Debug build location (Xcode)
            ".build/debug/apple-bridge",
            // Release build location
            ".build/release/apple-bridge",
            // Relative from test execution
            "../../../.build/debug/apple-bridge",
            "../../../.build/release/apple-bridge"
        ]

        // Try to find from BUILT_PRODUCTS_DIR if available
        if let builtProductsDir = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
            let path = URL(fileURLWithPath: builtProductsDir).appendingPathComponent("apple-bridge")
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        // Try to find from BUILD_DIR if available (Swift Package Manager)
        if let buildDir = ProcessInfo.processInfo.environment["BUILD_DIR"] {
            let path = URL(fileURLWithPath: buildDir).appendingPathComponent("apple-bridge")
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        // Try each possible path
        let currentDir = FileManager.default.currentDirectoryPath
        for relativePath in possiblePaths {
            let fullPath = URL(fileURLWithPath: currentDir).appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                return fullPath
            }
        }

        // Try to find it using `which`
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["apple-bridge"]

        let pipe = Pipe()
        whichProcess.standardOutput = pipe

        try? whichProcess.run()
        whichProcess.waitUntilExit()

        if whichProcess.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
        }

        throw E2ETestError.executableNotFound
    }

    // MARK: - 13.1 Main Entry Point Tests

    @Test("Server starts and responds to tools/list")
    func testServerStartsAndRespondsToToolsList() async throws {
        let (stdout, _) = try await runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/list"}
        """)

        #expect(stdout.contains("calendar_list"))
        #expect(stdout.contains("reminders_create"))
    }

    @Test("Server returns correct protocol version")
    func testServerReturnsCorrectProtocolVersion() async throws {
        let (stdout, _) = try await runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        """)

        // Parse the initialize response
        let lines = stdout.split(separator: "\n")
        let initResponse = lines.first { $0.contains("\"id\":1") }
        #expect(initResponse != nil)

        // Should contain protocol version
        #expect(initResponse?.contains("2024-11-05") == true)
    }

    @Test("Server reports correct version")
    func testServerReportsCorrectVersion() async throws {
        let (stdout, _) = try await runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        """)

        // Server should report its version in the response
        #expect(stdout.contains("apple-bridge"))
        #expect(stdout.contains("3.0")) // Major.minor version
    }

    // MARK: - 13.2 Signal Handling Tests

    @Test("Server handles SIGINT gracefully")
    func testServerHandlesSIGINT() async throws {
        // Find the built executable
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

        // Send initialize to start the server
        let initMessage = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}

        """
        if let data = initMessage.data(using: .utf8) {
            try stdinPipe.fileHandleForWriting.write(contentsOf: data)
        }

        // Give the server time to start
        try await Task.sleep(for: .milliseconds(100))

        // Send SIGINT
        process.interrupt()

        // Wait for graceful exit with timeout
        let startTime = Date()
        let timeout: TimeInterval = 2.0

        while process.isRunning {
            if Date().timeIntervalSince(startTime) > timeout {
                process.terminate()
                Issue.record("Server did not exit gracefully after SIGINT")
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        // Server should have exited with code 0 (graceful) or 130 (SIGINT standard)
        let exitCode = process.terminationStatus
        #expect(exitCode == 0 || exitCode == 130 || exitCode == 2,
                "Expected graceful exit (0, 130, or 2), got \(exitCode)")
    }
}

// MARK: - Error Types

/// Errors that can occur during E2E testing.
enum E2ETestError: Error, CustomStringConvertible {
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
