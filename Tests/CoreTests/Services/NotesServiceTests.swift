import Testing
import Foundation
@testable import Core
import TestUtilities

@Suite("NotesService Protocol Tests")
struct NotesServiceTests {

    // MARK: - Protocol Conformance Tests

    @Test func testMockNotesServiceConforms() async throws {
        let mock = MockNotesService()
        let page = try await mock.search(query: "test", limit: 10, includeBody: false)
        #expect(page.items.isEmpty)
    }

    @Test func testMockNotesServiceIsSendable() {
        let mock = MockNotesService()
        Task { @Sendable in _ = mock }
    }

    // MARK: - Search Tests

    @Test func testSearchNotesWithStubData() async throws {
        let mock = MockNotesService()
        await mock.setStubNotes([
            makeTestNote(id: "N1", title: "Meeting Notes"),
            makeTestNote(id: "N2", title: "Shopping List")
        ])

        let page = try await mock.search(query: "Meeting", limit: 10, includeBody: false)
        #expect(page.items.count == 1)
        #expect(page.items[0].title == "Meeting Notes")
    }

    @Test func testSearchNotesRespectsLimit() async throws {
        let mock = MockNotesService()
        await mock.setStubNotes([
            makeTestNote(id: "N1", title: "Note 1"),
            makeTestNote(id: "N2", title: "Note 2"),
            makeTestNote(id: "N3", title: "Note 3")
        ])

        let page = try await mock.search(query: "Note", limit: 2, includeBody: false)
        #expect(page.items.count == 2)
        #expect(page.hasMore == true)
    }

    @Test func testSearchNotesIncludeBodyFalse() async throws {
        let mock = MockNotesService()
        await mock.setStubNotes([
            makeTestNote(id: "N1", title: "Test", body: "Body content")
        ])

        let page = try await mock.search(query: "Test", limit: 10, includeBody: false)
        #expect(page.items.count == 1)
        #expect(page.items[0].body == nil)
    }

    @Test func testSearchNotesIncludeBodyTrue() async throws {
        let mock = MockNotesService()
        await mock.setStubNotes([
            makeTestNote(id: "N1", title: "Test", body: "Body content")
        ])

        let page = try await mock.search(query: "Test", limit: 10, includeBody: true)
        #expect(page.items.count == 1)
        #expect(page.items[0].body == "Body content")
    }

    // MARK: - Get Note Tests

    @Test func testGetNoteById() async throws {
        let mock = MockNotesService()
        let testNote = makeTestNote(id: "N123", title: "Important Note")
        await mock.setStubNotes([testNote])

        let note = try await mock.get(id: "N123")
        #expect(note.id == "N123")
        #expect(note.title == "Important Note")
    }

    @Test func testGetNoteNotFoundThrows() async throws {
        let mock = MockNotesService()
        await mock.setStubNotes([])

        await #expect(throws: (any Error).self) {
            _ = try await mock.get(id: "nonexistent")
        }
    }

    // MARK: - Create Note Tests

    @Test func testCreateNote() async throws {
        let mock = MockNotesService()

        let id = try await mock.create(title: "New Note", body: "Content", folderId: nil)

        #expect(!id.isEmpty)
    }

    // MARK: - Open Note Tests

    @Test func testOpenNote() async throws {
        let mock = MockNotesService()
        let testNote = makeTestNote(id: "N1")
        await mock.setStubNotes([testNote])

        try await mock.open(id: "N1")
        // No throw = success
    }
}
