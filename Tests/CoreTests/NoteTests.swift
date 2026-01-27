import Testing
import Foundation
@testable import Core

@Suite("Note Tests")
struct NoteTests {
    @Test func testNoteRoundTrip() throws {
        let note = Note(
            id: "N1",
            title: "Shopping List",
            body: "Milk, eggs, bread",
            folderId: "folder-1",
            modifiedAt: "2026-01-27T10:00:00Z"
        )
        let json = try JSONEncoder().encode(note)
        let decoded = try JSONDecoder().decode(Note.self, from: json)
        #expect(decoded.id == "N1")
        #expect(decoded.title == "Shopping List")
        #expect(decoded.body == "Milk, eggs, bread")
        #expect(decoded.folderId == "folder-1")
        #expect(decoded.modifiedAt == "2026-01-27T10:00:00Z")
    }

    @Test func testNoteWithNilOptionals() throws {
        let note = Note(
            id: "N2",
            title: nil,
            body: nil,
            folderId: nil,
            modifiedAt: "2026-01-27T10:00:00Z"
        )
        let json = try JSONEncoder().encode(note)
        let decoded = try JSONDecoder().decode(Note.self, from: json)
        #expect(decoded.title == nil)
        #expect(decoded.body == nil)
        #expect(decoded.folderId == nil)
    }

    @Test func testNoteEquality() {
        let note1 = Note(id: "N1", title: "Test", body: nil, folderId: nil, modifiedAt: "2026-01-27T10:00:00Z")
        let note2 = Note(id: "N1", title: "Test", body: nil, folderId: nil, modifiedAt: "2026-01-27T10:00:00Z")
        #expect(note1 == note2)
    }
}
