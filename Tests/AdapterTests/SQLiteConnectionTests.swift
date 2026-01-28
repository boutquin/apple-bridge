import Testing
import Foundation
@testable import Adapters
import Core

/// Tests for SQLiteConnection wrapper
@Suite("SQLite Connection Tests")
struct SQLiteConnectionTests {

    // MARK: - Test Fixture Path

    /// Path to the test-notes.sqlite fixture file.
    /// Uses Bundle.module when available, falls back to hardcoded path.
    private var testNotesFixturePath: String {
        // Try Bundle.module first (works when package resources are properly configured)
        if let url = Bundle.module.url(forResource: "test-notes", withExtension: "sqlite", subdirectory: "Fixtures") {
            return url.path
        }
        // Fallback to hardcoded path for development
        return "/Users/pierre/Documents/Code/boutquin/apple-bridge/Tests/AdapterTests/Fixtures/test-notes.sqlite"
    }

    // MARK: - Read-Only Mode Tests

    @Test("SQLite opens database in read-only mode")
    func testSQLiteOpensReadOnly() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)
        #expect(db.isOpen)
        // Read-only should succeed for queries
        let results = try db.query("SELECT 1 as test")
        #expect(results.count == 1)
    }

    @Test("SQLite throws when database file not found")
    func testSQLiteThrowsWhenNotFound() {
        let nonexistentPath = "/nonexistent/path/to/database.sqlite"
        #expect(throws: SQLiteError.self) {
            _ = try SQLiteConnection(path: nonexistentPath, readOnly: true)
        }
    }

    @Test("SQLite throws databaseNotFound with correct path")
    func testSQLiteThrowsDatabaseNotFoundWithPath() {
        let nonexistentPath = "/nonexistent/path/test.sqlite"
        do {
            _ = try SQLiteConnection(path: nonexistentPath, readOnly: true)
            Issue.record("Should have thrown")
        } catch let error as SQLiteError {
            #expect(error.userMessage.contains(nonexistentPath) || error.userMessage.contains("not found"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Busy Timeout Tests

    @Test("SQLite sets busy timeout")
    func testSQLiteBusyTimeout() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true, busyTimeoutMs: 5000)
        #expect(db.isOpen)
        // Busy timeout is set internally; verify connection works
        let results = try db.query("SELECT 1")
        #expect(results.count == 1)
    }

    @Test("SQLite uses default busy timeout")
    func testSQLiteDefaultBusyTimeout() throws {
        // Default timeout should be used when not specified
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)
        #expect(db.isOpen)
    }

    // MARK: - Query Tests

    @Test("SQLite executes simple query")
    func testSQLiteQuery() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)

        let results = try db.query("SELECT 1 as value, 'test' as name")
        #expect(results.count == 1)

        let row = results[0]
        #expect(row["value"] as? Int64 == 1)
        #expect(row["name"] as? String == "test")
    }

    @Test("SQLite query returns multiple rows")
    func testSQLiteQueryMultipleRows() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)

        let results = try db.query("SELECT 1 as n UNION SELECT 2 UNION SELECT 3")
        #expect(results.count == 3)
    }

    @Test("SQLite query with parameters")
    func testSQLiteQueryWithParameters() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)

        let results = try db.query("SELECT ? as value, ? as name", parameters: [42, "hello"])
        #expect(results.count == 1)

        let row = results[0]
        #expect(row["value"] as? Int64 == 42)
        #expect(row["name"] as? String == "hello")
    }

    @Test("SQLite throws on invalid SQL")
    func testSQLiteThrowsOnInvalidSQL() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)

        #expect(throws: SQLiteError.self) {
            _ = try db.query("INVALID SQL SYNTAX HERE")
        }
    }

    @Test("SQLite query error contains message")
    func testSQLiteQueryErrorContainsMessage() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)

        do {
            _ = try db.query("SELECT * FROM nonexistent_table")
            Issue.record("Should have thrown")
        } catch let error as SQLiteError {
            #expect(error.userMessage.contains("query") || error.userMessage.contains("failed") || error.userMessage.contains("no such table"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Connection Lifecycle Tests

    @Test("SQLite connection closes properly")
    func testSQLiteCloses() throws {
        var db: SQLiteConnection? = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)
        #expect(db?.isOpen == true)

        db?.close()
        #expect(db?.isOpen == false)
        db = nil
    }

    @Test("SQLite throws after close")
    func testSQLiteThrowsAfterClose() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)
        db.close()

        #expect(throws: SQLiteError.self) {
            _ = try db.query("SELECT 1")
        }
    }

    // MARK: - Sendable Tests

    @Test("SQLiteConnection is Sendable")
    func testSQLiteConnectionIsSendable() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)
        Task { @Sendable in _ = db }
    }

    // MARK: - Fixture Data Tests

    @Test("SQLite reads fixture data")
    func testSQLiteReadsFixtureData() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)

        let results = try db.query("SELECT COUNT(*) as count FROM ZICCLOUDSYNCINGOBJECT")
        #expect(results.count == 1)

        let count = results[0]["count"] as? Int64
        #expect(count == 3) // We inserted 3 notes in the fixture
    }

    @Test("SQLite queries fixture with WHERE clause")
    func testSQLiteQueriesFixtureWithWhere() throws {
        let db = try SQLiteConnection(path: testNotesFixturePath, readOnly: true)

        let results = try db.query(
            "SELECT ZTITLE1 FROM ZICCLOUDSYNCINGOBJECT WHERE ZTITLE1 LIKE ?",
            parameters: ["%Shopping%"]
        )
        #expect(results.count == 1)
        #expect(results[0]["ZTITLE1"] as? String == "Shopping List")
    }
}
