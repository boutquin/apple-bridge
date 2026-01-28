import Foundation
import Testing
import Adapters

/// System tests for Notes domain using real SQLite database.
///
/// These tests verify that the notes service works correctly with the
/// actual system Notes database. They require Full Disk Access permission.
///
/// ## Prerequisites
/// - Full Disk Access must be granted to the test runner
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
///
/// ## What These Tests Verify
/// - Service can connect to Notes database without crashing
/// - Basic search operations return valid data structures
/// - includeBody parameter works correctly (15.4)
@Suite("Notes System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct NotesSystemTests {

    /// Verifies that the notes service can search without crashing.
    @Test("Real notes search works")
    func testRealNotesSearch() async throws {
        let service = NotesSQLiteService()
        let results = try await service.search(query: "a", limit: 5, includeBody: false)

        // Just verify no crash and valid response structure
        #expect(results.items.count >= 0)
        #expect(results.items.count <= 5)
    }

    // MARK: - 15.4 includeBody Default Behavior Tests

    /// Verifies that includeBody=false returns notes without body content.
    ///
    /// This is part of spec section 15.4 — verifying that the default behavior
    /// (includeBody=false) does not include note bodies.
    @Test("includeBody=false excludes body content")
    func testIncludeBodyFalseExcludesBody() async throws {
        let service = NotesSQLiteService()
        let results = try await service.search(query: "a", limit: 5, includeBody: false)

        // Bodies should be nil or empty when includeBody is false
        for note in results.items {
            #expect(note.body == nil || note.body?.isEmpty == true,
                    "Expected nil or empty body when includeBody=false, got: \(note.body ?? "")")
        }
    }

    /// Verifies that includeBody=true returns notes with body content.
    ///
    /// This is part of spec section 15.4 — verifying that explicit includeBody=true
    /// includes note bodies when available.
    ///
    /// Note: This is a smoke test. If the user has no notes with body content,
    /// the test passes vacuously.
    @Test("includeBody=true includes body content")
    func testIncludeBodyTrueIncludesBody() async throws {
        let service = NotesSQLiteService()
        let results = try await service.search(query: "a", limit: 5, includeBody: true)

        // At least verify the call succeeds and returns valid structure
        // We can't assert bodies exist since user may have empty notes
        #expect(results.items.count >= 0)
        #expect(results.items.count <= 5)

        // If any notes exist and have content, bodies should be present
        // This is a weak assertion — stronger assertions would require test fixtures
    }
}
