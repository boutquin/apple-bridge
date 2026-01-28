import Testing
import Foundation
@testable import Adapters
@testable import Core

/// Tests for `NotesSQLiteService`, the SQLite-based Notes implementation.
///
/// These tests use a fixture database at `Tests/AdapterTests/Fixtures/test-notes.sqlite`
/// containing pre-populated notes for testing search, get, and open operations.
/// Create tests use a temporary writable database.
@Suite("NotesSQLiteService Tests")
struct NotesSQLiteServiceTests {

    // MARK: - Test Fixture Path

    /// Path to the test fixture database.
    private var fixturePath: String {
        // Use Bundle.module for SPM resources
        guard let path = Bundle.module.path(forResource: "test-notes", ofType: "sqlite", inDirectory: "Fixtures") else {
            fatalError("Test fixture not found: test-notes.sqlite")
        }
        return path
    }

    /// Creates a temporary writable copy of the fixture for write tests.
    private func makeWritableFixtureCopy() throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let tempPath = tempDir.appendingPathComponent("test-notes-\(UUID().uuidString).sqlite").path

        try FileManager.default.copyItem(atPath: fixturePath, toPath: tempPath)
        return tempPath
    }

    // MARK: - Search Tests

    @Test("search finds matching notes by title")
    func testSearchFindsMatchesByTitle() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        let results = try await service.search(query: "Shopping", limit: 10, includeBody: false)

        #expect(results.items.count >= 1)
        #expect(results.items.contains { $0.title?.contains("Shopping") == true })
    }

    @Test("search finds matching notes by snippet")
    func testSearchFindsMatchesBySnippet() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        let results = try await service.search(query: "Milk", limit: 10, includeBody: false)

        #expect(results.items.count >= 1)
        // "Milk" appears in the snippet of "Shopping List"
    }

    @Test("search is case-insensitive")
    func testSearchIsCaseInsensitive() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        let upperResults = try await service.search(query: "SHOPPING", limit: 10, includeBody: false)
        let lowerResults = try await service.search(query: "shopping", limit: 10, includeBody: false)

        #expect(upperResults.items.count == lowerResults.items.count)
    }

    @Test("search respects limit parameter")
    func testSearchRespectsLimit() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        let results = try await service.search(query: "", limit: 1, includeBody: false)

        #expect(results.items.count <= 1)
    }

    @Test("search omits body when includeBody is false")
    func testSearchOmitsBodyByDefault() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        let results = try await service.search(query: "Shopping", limit: 10, includeBody: false)

        for note in results.items {
            #expect(note.body == nil, "Body should be nil when includeBody is false")
        }
    }

    @Test("search includes body when includeBody is true")
    func testSearchIncludesBodyWhenRequested() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        let results = try await service.search(query: "Shopping", limit: 10, includeBody: true)

        // At least the Shopping List note should have body content
        let hasBody = results.items.contains { $0.body != nil && !$0.body!.isEmpty }
        #expect(hasBody, "At least one note should have body content when includeBody is true")
    }

    @Test("search returns empty results for non-matching query")
    func testSearchReturnsEmptyForNonMatchingQuery() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        let results = try await service.search(query: "xyz123nonexistent", limit: 10, includeBody: false)

        #expect(results.items.isEmpty)
    }

    @Test("search returns notes with correct structure")
    func testSearchReturnsNotesWithCorrectStructure() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        let results = try await service.search(query: "Shopping", limit: 10, includeBody: false)

        guard let note = results.items.first else {
            Issue.record("No notes returned")
            return
        }

        #expect(!note.id.isEmpty, "Note should have an ID")
        #expect(note.title != nil, "Note should have a title")
        #expect(!note.modifiedAt.isEmpty, "Note should have a modifiedAt date")
    }

    // MARK: - Get Tests

    @Test("get returns note by ID")
    func testGetReturnsNoteById() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        // First search to get an ID
        let searchResults = try await service.search(query: "Shopping", limit: 1, includeBody: false)
        guard let noteId = searchResults.items.first?.id else {
            Issue.record("No note found in fixture")
            return
        }

        let note = try await service.get(id: noteId)

        #expect(note.id == noteId)
        #expect(note.title?.contains("Shopping") == true)
    }

    @Test("get includes body content")
    func testGetIncludesBody() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        // First search to get an ID
        let searchResults = try await service.search(query: "Shopping", limit: 1, includeBody: false)
        guard let noteId = searchResults.items.first?.id else {
            Issue.record("No note found in fixture")
            return
        }

        let note = try await service.get(id: noteId)

        #expect(note.body != nil, "get() should include body by default")
    }

    @Test("get throws notFound for invalid ID")
    func testGetThrowsNotFoundForInvalidId() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        do {
            _ = try await service.get(id: "nonexistent-id-12345")
            Issue.record("Should have thrown ValidationError.notFound")
        } catch let error as ValidationError {
            // Expected
            #expect(error.userMessage.contains("Note"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Create Tests

    @Test("create returns new note ID")
    func testCreateReturnsNewId() async throws {
        let tempPath = try makeWritableFixtureCopy()
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let service = NotesSQLiteService(dbPath: tempPath)

        let id = try await service.create(title: "New Note", body: "Content here", folderId: nil)

        #expect(!id.isEmpty, "Create should return a non-empty ID")
    }

    @Test("create persists note that can be retrieved")
    func testCreatePersistsNote() async throws {
        let tempPath = try makeWritableFixtureCopy()
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let service = NotesSQLiteService(dbPath: tempPath)

        let id = try await service.create(title: "Test Note Title", body: "Test body content", folderId: nil)

        // Verify it was created by retrieving it
        let note = try await service.get(id: id)
        #expect(note.title == "Test Note Title")
        #expect(note.body == "Test body content")
    }

    @Test("create works without body")
    func testCreateWorksWithoutBody() async throws {
        let tempPath = try makeWritableFixtureCopy()
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let service = NotesSQLiteService(dbPath: tempPath)

        let id = try await service.create(title: "Title Only", body: nil, folderId: nil)

        let note = try await service.get(id: id)
        #expect(note.title == "Title Only")
    }

    @Test("create throws notFound for invalid folderId")
    func testCreateThrowsNotFoundForInvalidFolderId() async throws {
        let tempPath = try makeWritableFixtureCopy()
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let service = NotesSQLiteService(dbPath: tempPath)

        do {
            _ = try await service.create(title: "Test", body: nil, folderId: "999999")
            Issue.record("Should have thrown ValidationError.notFound")
        } catch let error as ValidationError {
            // Expected
            #expect(error.userMessage.contains("Folder"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Open Tests

    @Test("open succeeds for valid ID")
    func testOpenSucceedsForValidId() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        // Get a valid ID first
        let searchResults = try await service.search(query: "Shopping", limit: 1, includeBody: false)
        guard let noteId = searchResults.items.first?.id else {
            Issue.record("No note found in fixture")
            return
        }

        // Open should not throw for valid ID
        try await service.open(id: noteId)
        // No throw = success (opens Notes.app)
    }

    @Test("open throws notFound for invalid ID")
    func testOpenThrowsNotFoundForInvalidId() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        do {
            try await service.open(id: "nonexistent-id-12345")
            Issue.record("Should have thrown ValidationError.notFound")
        } catch let error as ValidationError {
            // Expected
            #expect(error.userMessage.contains("Note"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Service Properties

    @Test("NotesSQLiteService is Sendable")
    func testServiceIsSendable() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        // Compile-time check: can be passed across actor boundaries
        Task { @Sendable in
            _ = service
        }
    }

    @Test("NotesSQLiteService conforms to NotesService protocol")
    func testServiceConformsToProtocol() async throws {
        let service = NotesSQLiteService(dbPath: fixturePath)

        // Type check - service can be used as NotesService
        let _: any NotesService = service
    }

    // MARK: - Error Handling

    @Test("service throws for non-existent database path")
    func testServiceThrowsForNonExistentPath() async throws {
        let service = NotesSQLiteService(dbPath: "/nonexistent/path/database.sqlite")

        do {
            _ = try await service.search(query: "test", limit: 10, includeBody: false)
            Issue.record("Should have thrown an error")
        } catch {
            // Expected - database file not found
        }
    }
}
