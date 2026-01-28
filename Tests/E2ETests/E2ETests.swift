import Foundation
import Testing

/// End-to-end tests for the apple-bridge MCP server.
///
/// These tests verify that the server correctly handles MCP protocol messages
/// by starting the actual executable and communicating via stdin/stdout.
@Suite("E2E Tests")
struct E2ETests {

    // MARK: - 13.1 Main Entry Point Tests

    @Test("Server starts and responds to tools/list")
    func testServerStartsAndRespondsToToolsList() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/list"}
        """)

        #expect(stdout.contains("calendar_list"))
        #expect(stdout.contains("reminders_create"))
    }

    @Test("Server returns correct protocol version")
    func testServerReturnsCorrectProtocolVersion() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
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
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
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
