import Foundation

/// Protocol for interacting with Apple Notes.
///
/// Defines operations for searching, retrieving, creating, and opening notes.
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Example
/// ```swift
/// let service: NotesService = NotesSQLiteService()
/// let results = try await service.search(query: "meeting", limit: 10, includeBody: false)
/// ```
public protocol NotesService: Sendable {

    /// Searches for notes matching a query string.
    /// - Parameters:
    ///   - query: Text to search for in note titles and content.
    ///   - limit: Maximum number of notes to return.
    ///   - includeBody: Whether to include note body content in results.
    /// - Returns: A paginated response containing matching notes.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func search(query: String, limit: Int, includeBody: Bool) async throws -> Page<Note>

    /// Retrieves a specific note by its identifier.
    /// - Parameter id: Unique identifier of the note.
    /// - Returns: The note with body content.
    /// - Throws: `ValidationError.notFound` if the note is not found.
    func get(id: String) async throws -> Note

    /// Creates a new note.
    /// - Parameters:
    ///   - title: Title of the note.
    ///   - body: Body content of the note.
    ///   - folderId: Target folder identifier (uses default if nil).
    /// - Returns: Unique identifier of the created note.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func create(title: String, body: String?, folderId: String?) async throws -> String

    /// Opens a note in the Notes app.
    /// - Parameter id: Unique identifier of the note to open.
    /// - Throws: `ValidationError.notFound` if the note is not found.
    func open(id: String) async throws
}
