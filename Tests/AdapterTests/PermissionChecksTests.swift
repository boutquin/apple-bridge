import Testing
import Foundation
@testable import Adapters
import Core

/// Tests for permission checking utilities
@Suite("Permission Checks Tests")
struct PermissionChecksTests {

    // MARK: - Full Disk Access Tests

    @Test("FDA check returns a boolean")
    func testFDACheckReturnsBoolean() {
        // Just verify it returns without crashing
        let result = PermissionChecks.hasFullDiskAccess()
        #expect(result == true || result == false)
    }

    @Test("FDA check is repeatable")
    func testFDACheckIsRepeatable() {
        // Multiple calls should return consistent results
        let result1 = PermissionChecks.hasFullDiskAccess()
        let result2 = PermissionChecks.hasFullDiskAccess()
        #expect(result1 == result2)
    }

    // MARK: - Notes Database Path Tests

    @Test("Notes database path returns valid path")
    func testNotesDatabasePath() {
        let path = PermissionChecks.notesDatabasePath()
        #expect(path.contains("Library"))
        // Notes path contains "notes" (lowercase in group container name)
        #expect(path.lowercased().contains("notes"))
        #expect(path.hasSuffix(".sqlite") || path.hasSuffix(".db") || path.hasSuffix("NoteStore.sqlite"))
    }

    @Test("Notes database path is consistent")
    func testNotesDatabasePathIsConsistent() {
        let path1 = PermissionChecks.notesDatabasePath()
        let path2 = PermissionChecks.notesDatabasePath()
        #expect(path1 == path2)
    }

    // MARK: - Messages Database Path Tests

    @Test("Messages database path returns valid path")
    func testMessagesDatabasePath() {
        let path = PermissionChecks.messagesDatabasePath()
        #expect(path.contains("Library"))
        #expect(path.contains("Messages"))
        #expect(path.hasSuffix(".db") || path.hasSuffix("chat.db"))
    }

    @Test("Messages database path is consistent")
    func testMessagesDatabasePathIsConsistent() {
        let path1 = PermissionChecks.messagesDatabasePath()
        let path2 = PermissionChecks.messagesDatabasePath()
        #expect(path1 == path2)
    }

    // MARK: - Database Accessibility Tests

    @Test("canAccessNotesDatabase returns boolean")
    func testCanAccessNotesDatabaseReturnsBoolean() {
        let result = PermissionChecks.canAccessNotesDatabase()
        #expect(result == true || result == false)
    }

    @Test("canAccessMessagesDatabase returns boolean")
    func testCanAccessMessagesDatabaseReturnsBoolean() {
        let result = PermissionChecks.canAccessMessagesDatabase()
        #expect(result == true || result == false)
    }

    // MARK: - Error Generation Tests

    @Test("fdaRequiredError provides remediation steps")
    func testFDARequiredErrorProvidesRemediation() {
        let error = PermissionChecks.fdaRequiredError(for: "Notes")
        let message = error.userMessage

        // Should contain helpful information
        #expect(message.contains("Full Disk Access"))
        #expect(message.contains("System Settings") || message.contains("System Preferences"))
    }

    @Test("fdaRequiredError includes app name")
    func testFDARequiredErrorIncludesAppName() {
        let error = PermissionChecks.fdaRequiredError(for: "Messages")
        #expect(error.userMessage.contains("Messages"))
    }
}
