import Testing
import Foundation
@testable import Core

@Suite("DatabaseLockedError Tests")
struct DatabaseLockedErrorTests {
    @Test func testDatabaseLockedErrorMessage() {
        let error = DatabaseLockedError(database: "Notes")
        #expect(error.userMessage.contains("Notes"))
        #expect(error.userMessage.contains("Try again") || error.userMessage.contains("try again") || error.userMessage.contains("locked"))
    }

    @Test func testDatabaseLockedErrorIsDistinctFromSQLiteError() {
        // DatabaseLockedError is separate from SQLiteError for clearer error handling
        let lockedError = DatabaseLockedError(database: "Messages")
        let sqliteError = SQLiteError.openFailed(code: 5)

        // They should be different types (compile-time check via type annotation)
        let _: DatabaseLockedError = lockedError
        let _: SQLiteError = sqliteError

        // Both should have userMessage
        #expect(!lockedError.userMessage.isEmpty)
        #expect(!sqliteError.userMessage.isEmpty)
    }

    @Test func testDatabaseLockedErrorIsSendable() {
        let error = DatabaseLockedError(database: "Test")
        Task { @Sendable in
            _ = error
        }
    }

    @Test func testDifferentDatabases() {
        let notesError = DatabaseLockedError(database: "Notes")
        let messagesError = DatabaseLockedError(database: "Messages")

        #expect(notesError.userMessage.contains("Notes"))
        #expect(messagesError.userMessage.contains("Messages"))
    }
}
