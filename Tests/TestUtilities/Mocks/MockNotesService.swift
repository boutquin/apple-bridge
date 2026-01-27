import Foundation
import Core

/// Mock implementation of `NotesService` for testing.
public actor MockNotesService: NotesService {

    /// Stubbed notes to return from search operations.
    public var stubNotes: [Note] = []

    /// Tracks notes that have been created.
    public var createdNotes: [Note] = []

    /// Tracks IDs of notes that have been opened.
    public var openedNoteIds: [String] = []

    /// Error to throw (if set) for testing error scenarios.
    public var errorToThrow: (any Error)?

    /// Creates a new mock notes service.
    public init() {}

    /// Sets stubbed notes for testing.
    public func setStubNotes(_ notes: [Note]) {
        self.stubNotes = notes
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    public func search(query: String, limit: Int, includeBody: Bool) async throws -> Page<Note> {
        if let error = errorToThrow { throw error }

        let filtered = stubNotes.filter { note in
            (note.title?.localizedCaseInsensitiveContains(query) ?? false) ||
            (note.body?.localizedCaseInsensitiveContains(query) ?? false)
        }

        // Optionally strip body
        let results = includeBody ? filtered : filtered.map { note in
            Note(id: note.id, title: note.title, body: nil, folderId: note.folderId, modifiedAt: note.modifiedAt)
        }

        let limitedNotes = Array(results.prefix(limit))
        let hasMore = filtered.count > limit
        let nextCursor = hasMore ? "mock-cursor-\(limit)" : nil

        return Page(items: limitedNotes, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func get(id: String) async throws -> Note {
        if let error = errorToThrow { throw error }

        guard let note = stubNotes.first(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Note", id: id)
        }

        return note
    }

    public func create(title: String, body: String?, folderId: String?) async throws -> String {
        if let error = errorToThrow { throw error }

        let id = UUID().uuidString
        let note = Note(
            id: id,
            title: title,
            body: body,
            folderId: folderId,
            modifiedAt: ISO8601DateFormatter().string(from: Date())
        )

        createdNotes.append(note)
        stubNotes.append(note)

        return id
    }

    public func open(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard stubNotes.contains(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Note", id: id)
        }

        openedNoteIds.append(id)
    }
}
