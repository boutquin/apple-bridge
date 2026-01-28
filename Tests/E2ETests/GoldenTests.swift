import Foundation
import Testing

/// Golden tests for stdio framing validation.
///
/// These tests verify that the server correctly formats JSON-RPC output:
/// - Each line on stdout is valid JSON
/// - No blank lines in output
/// - Logs go to stderr, not stdout
@Suite("Golden Tests")
struct GoldenTests {

    // MARK: - 14.1 Stdio Framing Validation

    @Test("Stdout contains only valid JSON lines with no blank lines")
    func testStdioFramingNoBlankLines() async throws {
        let (stdout, stderr) = try await E2ETestHelper.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/list"}
        """)

        // Each non-empty line must be valid JSON
        for line in stdout.split(separator: "\n") where !line.isEmpty {
            let lineString = String(line)
            do {
                _ = try JSONSerialization.jsonObject(with: Data(lineString.utf8))
            } catch {
                Issue.record("Line is not valid JSON: \(lineString)")
            }
        }

        // No blank lines (consecutive newlines)
        #expect(!stdout.contains("\n\n"), "stdout should not contain blank lines")

        // No JSON-RPC messages on stderr (logs only)
        #expect(!stderr.contains("\"jsonrpc\""), "stderr should not contain JSON-RPC messages")
    }

    @Test("Logs go to stderr, not stdout")
    func testLogsGoToStderr() async throws {
        // Trigger an operation that might log (notes search may log if FDA not granted)
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"notes_search","arguments":{"searchText":"test"}}}
        """)

        // stdout should only contain JSON-RPC responses (lines starting with '{')
        for line in stdout.split(separator: "\n") where !line.isEmpty {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            #expect(trimmed.hasPrefix("{"), "stdout should only contain JSON: \(line)")
        }
    }
}
