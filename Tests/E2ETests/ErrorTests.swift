import Foundation
import Testing

/// Tests for error response validation.
///
/// These tests verify that the server correctly formats error responses
/// according to the MCP protocol.
@Suite("Error Response Tests")
struct ErrorResponseTests {

    // MARK: - 14.2 Error Response Validation

    @Test("Unknown tool error response contains UNKNOWN_TOOL and isError")
    func testErrorResponseFormat() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"unknown_tool","arguments":{}}}
        """)

        // Response should indicate this is an unknown tool error
        #expect(stdout.contains("UNKNOWN_TOOL"), "Error response should contain UNKNOWN_TOOL")

        // Response should be marked as an error (isError: true in content)
        #expect(stdout.contains("isError"), "Error response should contain isError field")
    }

    @Test("Error response is valid JSON")
    func testErrorResponseIsValidJSON() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"unknown_tool","arguments":{}}}
        """)

        // Find the error response line (id:2)
        let lines = stdout.split(separator: "\n")
        let errorResponseLine = lines.first { $0.contains("\"id\":2") }

        #expect(errorResponseLine != nil, "Should have response for id:2")

        if let responseLine = errorResponseLine {
            // Verify it's valid JSON
            do {
                _ = try JSONSerialization.jsonObject(with: Data(String(responseLine).utf8))
            } catch {
                Issue.record("Error response is not valid JSON: \(responseLine)")
            }
        }
    }

    @Test("Invalid arguments error response format")
    func testInvalidArgumentsErrorFormat() async throws {
        // Call a tool with missing required arguments
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"calendar_create","arguments":{}}}
        """)

        // Response should indicate invalid arguments
        #expect(stdout.contains("INVALID_ARGUMENTS") || stdout.contains("isError"),
                "Error response should indicate invalid arguments")
    }
}
