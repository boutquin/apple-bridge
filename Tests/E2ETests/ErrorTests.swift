import Foundation
import Testing

/// Tests for error response validation.
///
/// These tests verify that the server correctly formats error responses
/// according to the MCP protocol. Error responses must:
/// - Be valid JSON-RPC responses
/// - Include the `isError: true` flag in the content
/// - Include a descriptive error code (e.g., `UNKNOWN_TOOL`, `INVALID_ARGUMENTS`)
///
/// Proper error formatting is critical for clients to distinguish between
/// successful responses and errors, and to provide meaningful feedback to users.
@Suite("Error Response Tests")
struct ErrorResponseTests {

    // MARK: - 14.2 Error Response Validation

    /// Verifies that unknown tool requests return properly formatted UNKNOWN_TOOL errors.
    ///
    /// When a client requests a tool that doesn't exist, the server must return
    /// an error response with `UNKNOWN_TOOL` in the message and `isError: true`
    /// in the content, rather than crashing or returning an invalid response.
    @Test("Unknown tool error response contains UNKNOWN_TOOL and isError")
    func testErrorResponseFormat() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        \(E2ETestHelper.initializeMessage)
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"unknown_tool","arguments":{}}}
        """)

        // Response should indicate this is an unknown tool error
        #expect(stdout.contains("UNKNOWN_TOOL"), "Error response should contain UNKNOWN_TOOL")

        // Response should be marked as an error (isError: true in content)
        #expect(stdout.contains("isError"), "Error response should contain isError field")
    }

    /// Verifies that error responses are valid JSON that clients can parse.
    ///
    /// Even when returning an error, the response must be valid JSON-RPC
    /// so clients can parse it and extract the error information.
    @Test("Error response is valid JSON")
    func testErrorResponseIsValidJSON() async throws {
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        \(E2ETestHelper.initializeMessage)
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"unknown_tool","arguments":{}}}
        """)

        // Find the error response line (id:2)
        let lines = stdout.split(separator: "\n")
        let errorResponseLine = lines.first { $0.contains("\"id\":2") }

        #expect(errorResponseLine != nil, "Should have response for id:2")

        if let responseLine = errorResponseLine {
            // Verify it's valid JSON
            let parsed = try? JSONSerialization.jsonObject(with: Data(String(responseLine).utf8))
            #expect(parsed != nil, "Error response is not valid JSON: \(responseLine)")
        }
    }

    /// Verifies that missing required arguments return meaningful error responses.
    ///
    /// When a client calls a tool without providing required arguments,
    /// the server must return an error response with `isError: true` and
    /// a message indicating which parameter is missing.
    @Test("Invalid arguments error response format")
    func testInvalidArgumentsErrorFormat() async throws {
        // Call a tool with missing required arguments (calendar_create requires title, startDate, endDate)
        let (stdout, _) = try await E2ETestHelper.runAppleBridge(input: """
        \(E2ETestHelper.initializeMessage)
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"calendar_create","arguments":{}}}
        """)

        // Response should indicate an error occurred
        #expect(stdout.contains("isError"), "Error response should contain isError field")

        // Response should indicate which parameter is missing
        #expect(stdout.contains("Missing required parameter"),
                "Error response should indicate missing required parameter")
    }
}
