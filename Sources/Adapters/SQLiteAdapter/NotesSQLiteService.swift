import Foundation
import Core

/// SQLite-based implementation of `NotesService`.
///
/// Uses a `NotesAdapterProtocol` to interact with the Notes database.
/// This enables dependency injection for testing.
///
/// Requires Full Disk Access permission to read the Notes database.
///
/// ## Usage
/// ```swift
/// let service = NotesSQLiteService()
/// let results = try await service.search(query: "meeting", limit: 10, includeBody: false)
/// ```
///
/// For testing with a mock adapter:
/// ```swift
/// let adapter = MockNotesAdapter()
/// let service = NotesSQLiteService(adapter: adapter)
/// ```
public struct NotesSQLiteService: NotesService, Sendable {

    /// The adapter to use for notes operations.
    private let adapter: any NotesAdapterProtocol

    // MARK: - Initialization

    /// Creates a new Notes service using the default adapter.
    ///
    /// Uses the default path: `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`
    public init() {
        self.adapter = RealNotesAdapter()
    }

    /// Creates a new Notes service with a custom adapter (for testing).
    ///
    /// - Parameter adapter: The notes adapter to use.
    public init(adapter: any NotesAdapterProtocol) {
        self.adapter = adapter
    }

    /// Creates a new Notes service with a custom database path (for backward compatibility).
    ///
    /// Useful for testing with fixture databases.
    ///
    /// - Parameters:
    ///   - dbPath: Path to the SQLite database file.
    ///   - readOnly: Whether to open read-only. Defaults to `true`.
    public init(dbPath: String, readOnly: Bool = true) {
        self.adapter = RealNotesAdapter(dbPath: dbPath, readOnly: readOnly)
    }

    // MARK: - NotesService Protocol

    /// Searches notes by query string.
    ///
    /// Searches in both note titles and snippets (body text).
    ///
    /// - Parameters:
    ///   - query: The search query. Use empty string to match all notes.
    ///   - limit: Maximum number of notes to return.
    ///   - includeBody: Whether to include note body content in results.
    /// - Returns: A paginated page of matching notes.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if database access is denied.
    /// - Throws: `SQLiteError` for database-related errors.
    public func search(query: String, limit: Int, includeBody: Bool) async throws -> Page<Note> {
        let noteData = try await adapter.searchNotes(query: query, limit: limit, includeBody: includeBody)
        let notes = noteData.map { toNote($0) }
        // Simple pagination - no cursor support for search in v1
        return Page(items: notes, nextCursor: nil, hasMore: false)
    }

    /// Retrieves a note by its ID.
    ///
    /// - Parameter id: The note's unique identifier (Z_PK as string).
    /// - Returns: The note with full body content.
    /// - Throws: `ValidationError.notFound` if no note exists with the given ID.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if database access is denied.
    /// - Throws: `SQLiteError` for database-related errors.
    public func get(id: String) async throws -> Note {
        let noteData = try await adapter.fetchNote(id: id)
        return toNote(noteData)
    }

    /// Creates a new note.
    ///
    /// - Parameters:
    ///   - title: The note title.
    ///   - body: Optional note body content.
    ///   - folderId: Optional folder ID. If nil, uses default folder (Z_PK=1).
    /// - Returns: The ID of the newly created note.
    /// - Throws: `ValidationError.notFound` if the specified folder does not exist.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if database access is denied.
    /// - Throws: `SQLiteError` for database-related errors.
    public func create(title: String, body: String?, folderId: String?) async throws -> String {
        try await adapter.createNote(title: title, body: body, folderId: folderId)
    }

    /// Opens a note in the Notes app.
    ///
    /// Currently activates Notes.app but does not navigate to the specific note.
    /// Full implementation would require `notes://` URL scheme or AppleScript navigation.
    ///
    /// - Parameter id: The note's unique identifier.
    /// - Throws: `ValidationError.notFound` if no note exists with the given ID.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if database access is denied.
    public func open(id: String) async throws {
        try await adapter.openNote(id: id)
    }

    // MARK: - Private Helpers

    /// Converts NoteData to Note model.
    private func toNote(_ data: NoteData) -> Note {
        Note(
            id: data.id,
            title: data.title,
            body: data.body,
            folderId: data.folderId,
            modifiedAt: data.modifiedAt
        )
    }
}
