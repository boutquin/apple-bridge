import Testing
import Foundation
@testable import Core

@Suite("SQLiteError Tests")
struct SQLiteErrorTests {
    @Test func testDatabaseNotFoundMessage() {
        let error = SQLiteError.databaseNotFound(path: "/path/to/db.sqlite")
        #expect(error.userMessage.contains("/path/to/db.sqlite"))
        #expect(error.userMessage.contains("not found"))
    }

    @Test func testOpenFailedMessage() {
        let error = SQLiteError.openFailed(code: 14)
        #expect(error.userMessage.contains("14"))
        #expect(error.userMessage.contains("open"))
    }

    @Test func testQueryFailedMessage() {
        let error = SQLiteError.queryFailed(message: "syntax error")
        #expect(error.userMessage.contains("syntax error"))
    }

    @Test func testUnsupportedSchemaMessage() {
        let error = SQLiteError.unsupportedSchema(details: "missing column ZTITLE")
        #expect(error.userMessage.contains("missing column ZTITLE"))
        #expect(error.userMessage.contains("schema"))
    }

    @Test func testAllSQLiteErrorsAreSendable() {
        let errors: [SQLiteError] = [
            .databaseNotFound(path: "/test"),
            .openFailed(code: 1),
            .queryFailed(message: "error"),
            .unsupportedSchema(details: "details")
        ]
        Task { @Sendable in
            _ = errors
        }
    }
}
