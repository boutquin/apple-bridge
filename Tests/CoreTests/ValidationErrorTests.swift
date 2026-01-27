import Testing
import Foundation
@testable import Core

@Suite("ValidationError Tests")
struct ValidationErrorTests {
    @Test func testValidationErrorMissingField() {
        let error = ValidationError.missingRequired(field: "title")
        #expect(error.userMessage.contains("title"))
        #expect(error.userMessage.contains("Missing") || error.userMessage.contains("required"))
    }

    @Test func testValidationErrorInvalidFormat() {
        let error = ValidationError.invalidFormat(field: "date", expected: "ISO8601")
        #expect(error.userMessage.contains("date"))
        #expect(error.userMessage.contains("ISO8601"))
    }

    @Test func testValidationErrorInvalidCursor() {
        let error = ValidationError.invalidCursor(reason: "malformed base64")
        #expect(error.userMessage.contains("malformed base64"))
        #expect(error.userMessage.contains("cursor") || error.userMessage.contains("Cursor"))
    }

    @Test func testValidationErrorInvalidField() {
        let error = ValidationError.invalidField(field: "foo", allowed: ["id", "title", "date"])
        #expect(error.userMessage.contains("foo"))
        #expect(error.userMessage.contains("id"))
        #expect(error.userMessage.contains("title"))
        #expect(error.userMessage.contains("date"))
    }

    @Test func testValidationErrorNotFound() {
        let error = ValidationError.notFound(resource: "CalendarEvent", id: "E123")
        #expect(error.userMessage.contains("CalendarEvent"))
        #expect(error.userMessage.contains("E123"))
        #expect(error.userMessage.contains("not found"))
    }

    @Test func testAllValidationErrorsAreSendable() {
        let errors: [ValidationError] = [
            .missingRequired(field: "test"),
            .invalidFormat(field: "test", expected: "format"),
            .invalidCursor(reason: "reason"),
            .invalidField(field: "test", allowed: ["a", "b"]),
            .notFound(resource: "Resource", id: "123")
        ]
        Task { @Sendable in
            _ = errors
        }
    }
}
