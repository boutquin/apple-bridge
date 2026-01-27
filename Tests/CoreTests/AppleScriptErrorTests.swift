import Testing
import Foundation
@testable import Core

@Suite("AppleScriptError Tests")
struct AppleScriptErrorTests {
    @Test func testExecutionFailedMessage() {
        let error = AppleScriptError.executionFailed(message: "Script error at line 5")
        #expect(error.userMessage.contains("Script error at line 5"))
        #expect(error.userMessage.contains("execution"))
    }

    @Test func testTimeoutMessage() {
        let error = AppleScriptError.timeout(seconds: 30)
        #expect(error.userMessage.contains("30"))
        #expect(error.userMessage.contains("timeout") || error.userMessage.contains("Timeout"))
    }

    @Test func testCompilationFailedMessage() {
        let error = AppleScriptError.compilationFailed(message: "Expected end of line")
        #expect(error.userMessage.contains("Expected end of line"))
        #expect(error.userMessage.contains("compil"))
    }

    @Test func testAllAppleScriptErrorsAreSendable() {
        let errors: [AppleScriptError] = [
            .executionFailed(message: "test"),
            .timeout(seconds: 10),
            .compilationFailed(message: "error")
        ]
        Task { @Sendable in
            _ = errors
        }
    }
}
