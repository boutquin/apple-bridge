import Foundation
import Testing

/// End-to-end tests for the apple-bridge MCP server.
///
/// These tests verify that the server correctly handles MCP protocol messages
/// by starting the actual executable and communicating via stdin/stdout.
/// Unlike unit tests that mock dependencies, E2E tests exercise the full
/// server stack including process management, JSON-RPC parsing, and signal handling.
///
/// ## Prerequisites
/// - The project must be built (`swift build`) before running these tests
/// - The executable must be accessible in the build directory
///
/// ## Test Categories
/// - **13.1 Main Entry Point**: Server startup, protocol version, tool listing
/// - **13.2 Signal Handling**: Graceful shutdown on SIGINT
@Suite("E2E Tests")
struct E2ETests {

    // MARK: - 13.1 Main Entry Point Tests

    /// Verifies that the server starts successfully and responds to tools/list.
    ///
    /// This is the most basic E2E test - if the server can initialize and
    /// list its tools, the core MCP infrastructure is working.
    @Test("Server starts and responds to tools/list")
    func testServerStartsAndRespondsToToolsList() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        \(E2ETestHelper.initializeMessage)
        {"jsonrpc":"2.0","id":2,"method":"tools/list"}
        """)

        #expect(stdout.contains("calendar_list"))
        #expect(stdout.contains("reminders_create"))
    }

    /// Verifies that the server reports the correct MCP protocol version.
    ///
    /// Protocol version compatibility is critical for client-server communication.
    /// The server must report the version it was built against.
    @Test("Server returns correct protocol version")
    func testServerReturnsCorrectProtocolVersion() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: E2ETestHelper.initializeMessage)

        // Parse the initialize response
        let lines = stdout.split(separator: "\n")
        let initResponse = lines.first { $0.contains("\"id\":1") }
        #expect(initResponse != nil)

        // Should contain protocol version
        #expect(initResponse?.contains("2024-11-05") == true)
    }

    /// Verifies that the server reports its name and version in the initialize response.
    ///
    /// Clients may use server info for logging, debugging, or compatibility checks.
    @Test("Server reports correct version")
    func testServerReportsCorrectVersion() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: E2ETestHelper.initializeMessage)

        // Server should report its version in the response
        #expect(stdout.contains("apple-bridge"))
        #expect(stdout.contains("3.0")) // Major.minor version
    }

    // MARK: - 13.2 Signal Handling Tests

    /// Verifies that the server shuts down gracefully when receiving SIGINT.
    ///
    /// Graceful shutdown is important for:
    /// - Releasing system resources properly
    /// - Completing in-flight operations
    /// - Not leaving zombie processes
    ///
    /// The server should exit with code 0 (graceful), 130 (SIGINT standard), or 2.
    @Test("Server handles SIGINT gracefully")
    func testServerHandlesSIGINT() async throws {
        // Find the built executable
        let executableURL = try E2ETestHelper.findExecutable()

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
        let initMessage = E2ETestHelper.initializeMessage + "\n"
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
                #expect(Bool(false), "Server did not exit gracefully after SIGINT within \(timeout) seconds")
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
