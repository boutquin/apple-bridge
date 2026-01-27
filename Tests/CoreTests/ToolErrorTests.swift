import Testing
import Foundation
@testable import Core

@Suite("ToolError Tests")
struct ToolErrorTests {
    @Test func testDeadlineExceededMessage() {
        let error = ToolError.deadlineExceeded(seconds: 30)
        #expect(error.userMessage.contains("30"))
        #expect(error.userMessage.contains("deadline") || error.userMessage.contains("timeout"))
    }

    @Test func testCancelledMessage() {
        let error = ToolError.cancelled
        #expect(error.userMessage.contains("cancel"))
    }

    @Test func testUnknownToolMessage() {
        let error = ToolError.unknownTool(name: "invalid_tool")
        #expect(error.userMessage.contains("invalid_tool"))
        #expect(error.userMessage.contains("unknown") || error.userMessage.contains("Unknown"))
    }

    @Test func testInternalErrorMessage() {
        let error = ToolError.internalError(message: "Unexpected state")
        #expect(error.userMessage.contains("Unexpected state"))
    }

    @Test func testAllToolErrorsAreSendable() {
        let errors: [ToolError] = [
            .deadlineExceeded(seconds: 30),
            .cancelled,
            .unknownTool(name: "test"),
            .internalError(message: "error")
        ]
        Task { @Sendable in
            _ = errors
        }
    }
}
