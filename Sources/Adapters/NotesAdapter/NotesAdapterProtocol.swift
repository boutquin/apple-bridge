import Foundation
import Core

// MARK: - Notes Data Transfer Objects

/// Lightweight data representation of a note.
///
/// This struct provides a Sendable, Codable representation of notes
/// that can be safely passed across actor boundaries without requiring direct
/// framework access. Used as the boundary type between adapter implementations
/// (SQLite, AppleScript, etc.) and the service layer.
public struct NoteData: Sendable, Equatable, Codable {
    /// Unique identifier for the note.
    public let id: String

    /// Title of the note, if available.
    public let title: String?

    /// Body content of the note, if included.
    public let body: String?

    /// Identifier of the folder containing this note.
    public let folderId: String?

    /// Last modification date in ISO 8601 format.
    public let modifiedAt: String

    /// Creates a new note data instance.
    /// - Parameters:
    ///   - id: Unique identifier for the note.
    ///   - title: Note title.
    ///   - body: Note body content.
    ///   - folderId: Containing folder identifier.
    ///   - modifiedAt: Last modification date in ISO 8601 format.
    public init(
        id: String,
        title: String? = nil,
        body: String? = nil,
        folderId: String? = nil,
        modifiedAt: String
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.folderId = folderId
        self.modifiedAt = modifiedAt
    }
}

/// Lightweight data representation of a notes folder.
///
/// This struct provides a Sendable representation of notes folders that can be
/// safely passed across actor boundaries. Used as the boundary type between
/// adapter implementations and the service layer.
public struct NoteFolderData: Sendable, Equatable, Codable {
    /// Unique identifier for the folder.
    public let id: String

    /// Display name of the folder.
    public let name: String

    /// Creates a new note folder data instance.
    /// - Parameters:
    ///   - id: Unique identifier for the folder.
    ///   - name: Display name of the folder.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Protocol

/// Protocol for interacting with Apple Notes.
///
/// This protocol abstracts notes operations to enable testing with mock implementations
/// and to support multiple backend implementations (SQLite, AppleScript, etc.).
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Implementation Notes
/// - SQLite implementation reads directly from the Notes database (requires Full Disk Access)
/// - AppleScript implementation uses osascript for notes access
/// - The protocol uses generic data transfer objects (NoteData, NoteFolderData) to
///   decouple from specific implementation details
///
/// ## Example
/// ```swift
/// let adapter: NotesAdapterProtocol = SQLiteNotesAdapter()
/// let notes = try await adapter.searchNotes(query: "meeting", limit: 10, includeBody: false)
/// ```
public protocol NotesAdapterProtocol: Sendable {

    // MARK: - Search Operations

    /// Searches for notes matching a query string.
    /// - Parameters:
    ///   - query: Text to search for in note titles and content.
    ///   - limit: Maximum number of notes to return.
    ///   - includeBody: Whether to include note body content in results.
    /// - Returns: Array of matching note data objects.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func searchNotes(query: String, limit: Int, includeBody: Bool) async throws -> [NoteData]

    // MARK: - Note Operations

    /// Fetches a specific note by its identifier.
    /// - Parameter id: Unique identifier of the note.
    /// - Returns: The note data with body content.
    /// - Throws: `ValidationError.notFound` if the note is not found.
    func fetchNote(id: String) async throws -> NoteData

    /// Creates a new note.
    /// - Parameters:
    ///   - title: Title of the note.
    ///   - body: Body content of the note.
    ///   - folderId: Target folder identifier (uses default if nil).
    /// - Returns: Unique identifier of the created note.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func createNote(title: String, body: String?, folderId: String?) async throws -> String

    /// Opens a note in the Notes app.
    /// - Parameter id: Unique identifier of the note to open.
    /// - Throws: `ValidationError.notFound` if the note is not found.
    func openNote(id: String) async throws
}
