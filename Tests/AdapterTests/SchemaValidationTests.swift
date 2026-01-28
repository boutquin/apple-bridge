import Testing
import Foundation
@testable import Adapters
import Core

/// Tests for SQLite schema validation utilities
@Suite("Schema Validation Tests")
struct SchemaValidationTests {

    // MARK: - Test Fixture Paths

    private var testNotesFixturePath: String {
        if let url = Bundle.module.url(forResource: "test-notes", withExtension: "sqlite", subdirectory: "Fixtures") {
            return url.path
        }
        return "/Users/pierre/Documents/Code/boutquin/apple-bridge/Tests/AdapterTests/Fixtures/test-notes.sqlite"
    }

    private var testMessagesFixturePath: String {
        if let url = Bundle.module.url(forResource: "test-messages", withExtension: "sqlite", subdirectory: "Fixtures") {
            return url.path
        }
        return "/Users/pierre/Documents/Code/boutquin/apple-bridge/Tests/AdapterTests/Fixtures/test-messages.sqlite"
    }

    // MARK: - Notes Schema Validation Tests

    @Test("Notes schema validation passes for valid database")
    func testNotesSchemaValidationPasses() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)
        try SchemaValidator.validateNotesSchema(db)
        // Should not throw
    }

    @Test("Notes schema validation detects missing table")
    func testNotesSchemaDetectsMissingTable() throws {
        // Create an empty in-memory database
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("empty-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        // Create empty database
        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        _ = try db.query("CREATE TABLE dummy (id INTEGER)")

        #expect(throws: SQLiteError.self) {
            try SchemaValidator.validateNotesSchema(db)
        }
    }

    @Test("Notes schema validation error mentions required table")
    func testNotesSchemaErrorMentionsTable() throws {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("empty-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        _ = try db.query("CREATE TABLE dummy (id INTEGER)")

        do {
            try SchemaValidator.validateNotesSchema(db)
            Issue.record("Should have thrown")
        } catch let error as SQLiteError {
            #expect(error.userMessage.contains("ZICCLOUDSYNCINGOBJECT") || error.userMessage.contains("schema") || error.userMessage.contains("table"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("Notes schema validation checks required columns")
    func testNotesSchemaChecksColumns() throws {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("bad-schema-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        // Create table with wrong columns
        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        _ = try db.query("CREATE TABLE ZICCLOUDSYNCINGOBJECT (wrong_column TEXT)")

        #expect(throws: SQLiteError.self) {
            try SchemaValidator.validateNotesSchema(db)
        }
    }

    // MARK: - Messages Schema Validation Tests

    @Test("Messages schema validation passes for valid database")
    func testMessagesSchemaValidationPasses() throws {
        let db = try SQLiteConnection(path: testMessagesFixturePath, readOnly: true)
        try SchemaValidator.validateMessagesSchema(db)
        // Should not throw
    }

    @Test("Messages schema validation detects missing message table")
    func testMessagesSchemaDetectsMissingMessageTable() throws {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("no-msg-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        _ = try db.query("CREATE TABLE chat (ROWID INTEGER, chat_identifier TEXT)")
        _ = try db.query("CREATE TABLE handle (ROWID INTEGER, id TEXT)")
        // Missing: message table

        #expect(throws: SQLiteError.self) {
            try SchemaValidator.validateMessagesSchema(db)
        }
    }

    @Test("Messages schema validation detects missing chat table")
    func testMessagesSchemaDetectsMissingChatTable() throws {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("no-chat-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        _ = try db.query("CREATE TABLE message (ROWID INTEGER, text TEXT, date INTEGER)")
        _ = try db.query("CREATE TABLE handle (ROWID INTEGER, id TEXT)")
        // Missing: chat table

        #expect(throws: SQLiteError.self) {
            try SchemaValidator.validateMessagesSchema(db)
        }
    }

    @Test("Messages schema validation detects missing handle table")
    func testMessagesSchemaDetectsMissingHandleTable() throws {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("no-handle-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        _ = try db.query("CREATE TABLE message (ROWID INTEGER, text TEXT, date INTEGER)")
        _ = try db.query("CREATE TABLE chat (ROWID INTEGER, chat_identifier TEXT)")
        // Missing: handle table

        #expect(throws: SQLiteError.self) {
            try SchemaValidator.validateMessagesSchema(db)
        }
    }

    @Test("Messages schema validation checks required columns")
    func testMessagesSchemaChecksColumns() throws {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("bad-msg-schema-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        // Create tables but with missing columns
        _ = try db.query("CREATE TABLE message (ROWID INTEGER)")  // Missing: text, date, is_read
        _ = try db.query("CREATE TABLE chat (ROWID INTEGER, chat_identifier TEXT)")
        _ = try db.query("CREATE TABLE handle (ROWID INTEGER, id TEXT)")

        #expect(throws: SQLiteError.self) {
            try SchemaValidator.validateMessagesSchema(db)
        }
    }

    // MARK: - Generic Schema Validation Tests

    @Test("Schema validation with custom tables and columns")
    func testGenericSchemaValidation() throws {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("custom-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        _ = try db.query("CREATE TABLE users (id INTEGER, name TEXT, email TEXT)")

        // Should pass with correct schema
        try SchemaValidator.validate(
            db,
            requiredTables: ["users"],
            requiredColumns: ["users": ["id", "name", "email"]]
        )
    }

    @Test("Schema validation fails with missing custom column")
    func testGenericSchemaValidationMissingColumn() throws {
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("missing-col-\(UUID()).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let db = try SQLiteConnection(path: tempPath, readOnly: false)
        _ = try db.query("CREATE TABLE users (id INTEGER, name TEXT)")  // Missing: email

        #expect(throws: SQLiteError.self) {
            try SchemaValidator.validate(
                db,
                requiredTables: ["users"],
                requiredColumns: ["users": ["id", "name", "email"]]
            )
        }
    }
}
