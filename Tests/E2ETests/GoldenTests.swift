import Foundation
import Testing

/// Golden tests for stdio framing validation.
///
/// These tests verify that the server correctly formats JSON-RPC output
/// according to the MCP protocol specification:
/// - Each line on stdout is valid JSON (single-line JSON-RPC messages)
/// - No blank lines in output (clean framing)
/// - Logs go to stderr, not stdout (separation of concerns)
///
/// These are "golden" tests because they validate the exact output format
/// that clients depend on for correct protocol operation.
@Suite("Golden Tests")
struct GoldenTests {

    // MARK: - 14.1 Stdio Framing Validation

    /// Verifies that all stdout output is valid JSON with no blank lines.
    ///
    /// The MCP protocol requires that each line on stdout is a complete,
    /// valid JSON-RPC message. Blank lines would break JSON parsing in clients.
    /// This test also verifies that JSON-RPC messages never appear on stderr.
    @Test("Stdout contains only valid JSON lines with no blank lines")
    func testStdioFramingNoBlankLines() async throws {
        let (stdout, stderr) = try await E2ETestHelper.runAppleBridge(input: """
        \(E2ETestHelper.initializeMessage)
        {"jsonrpc":"2.0","id":2,"method":"tools/list"}
        """)

        // Each non-empty line must be valid JSON
        for line in stdout.split(separator: "\n") where !line.isEmpty {
            let lineString = String(line)
            let parsed = try? JSONSerialization.jsonObject(with: Data(lineString.utf8))
            #expect(parsed != nil, "Line is not valid JSON: \(lineString)")
        }

        // No blank lines (consecutive newlines)
        #expect(!stdout.contains("\n\n"), "stdout should not contain blank lines")

        // No JSON-RPC messages on stderr (logs only)
        #expect(!stderr.contains("\"jsonrpc\""), "stderr should not contain JSON-RPC messages")
    }

    /// Verifies that diagnostic logs go to stderr, keeping stdout clean for JSON-RPC.
    ///
    /// MCP clients parse stdout as JSON-RPC. Any non-JSON content (like log messages)
    /// would break parsing. This test triggers an operation that may produce logs
    /// and verifies they don't pollute stdout.
    @Test("Logs go to stderr, not stdout")
    func testLogsGoToStderr() async throws {
        // Trigger an operation that might log (notes search may log if FDA not granted)
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        \(E2ETestHelper.initializeMessage)
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"notes_search","arguments":{"searchText":"test"}}}
        """)

        // stdout should only contain JSON-RPC responses (lines starting with '{')
        for line in stdout.split(separator: "\n") where !line.isEmpty {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            #expect(trimmed.hasPrefix("{"), "stdout should only contain JSON: \(line)")
        }
    }
}
