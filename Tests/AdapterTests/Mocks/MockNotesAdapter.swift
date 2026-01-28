import Foundation
import Core
import Adapters

/// Mock implementation of `NotesAdapterProtocol` for testing.
///
/// Provides stubbed data and tracks method calls for verification in tests.
/// All methods are actor-isolated for thread safety.
public actor MockNotesAdapter: NotesAdapterProtocol {

    // MARK: - Stub Data

    /// Stubbed notes to return from operations.
    private var stubNotes: [NoteData] = []

    /// ID counter for creating new notes.
    private var nextNoteId: Int = 1000

    /// Error to throw (if set) for testing error scenarios.
    private var errorToThrow: (any Error)?

    // MARK: - Tracking

    /// Tracks search queries made.
    private var searchQueries: [(query: String, limit: Int, includeBody: Bool)] = []

    /// Tracks notes created.
    private var createdNotes: [(title: String, body: String?, folderId: String?)] = []

    /// Tracks notes opened.
    private var openedNoteIds: [String] = []

    // MARK: - Initialization

    /// Creates a new mock notes adapter.
    public init() {}

    // MARK: - Setup Methods

    /// Sets stubbed notes for testing.
    public func setStubNotes(_ notes: [NoteData]) {
        self.stubNotes = notes
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    // MARK: - Verification Methods

    /// Gets the search queries for verification.
    public func getSearchQueries() -> [(query: String, limit: Int, includeBody: Bool)] {
        return searchQueries
    }

    /// Gets the created notes for verification.
    public func getCreatedNotes() -> [(title: String, body: String?, folderId: String?)] {
        return createdNotes
    }

    /// Gets the opened note IDs for verification.
    public func getOpenedNoteIds() -> [String] {
        return openedNoteIds
    }

    // MARK: - NotesAdapterProtocol

    public func searchNotes(query: String, limit: Int, includeBody: Bool) async throws -> [NoteData] {
        if let error = errorToThrow { throw error }
        searchQueries.append((query: query, limit: limit, includeBody: includeBody))

        // Filter by query in title or body
        let filtered = stubNotes.filter { note in
            (note.title?.localizedCaseInsensitiveContains(query) ?? false) ||
            (note.body?.localizedCaseInsensitiveContains(query) ?? false)
        }

        // Return with or without body based on includeBody flag
        let results = includeBody ? filtered : filtered.map { note in
            NoteData(id: note.id, title: note.title, body: nil, folderId: note.folderId, modifiedAt: note.modifiedAt)
        }

        return Array(results.prefix(limit))
    }

    public func fetchNote(id: String) async throws -> NoteData {
        if let error = errorToThrow { throw error }

        guard let note = stubNotes.first(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Note", id: id)
        }

        return note
    }

    public func createNote(title: String, body: String?, folderId: String?) async throws -> String {
        if let error = errorToThrow { throw error }

        createdNotes.append((title: title, body: body, folderId: folderId))

        let newId = String(nextNoteId)
        nextNoteId += 1

        // Add to stub notes for subsequent operations
        let newNote = NoteData(
            id: newId,
            title: title,
            body: body,
            folderId: folderId,
            modifiedAt: ISO8601DateFormatter().string(from: Date())
        )
        stubNotes.append(newNote)

        return newId
    }

    public func openNote(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard stubNotes.contains(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Note", id: id)
        }

        openedNoteIds.append(id)
    }
}
