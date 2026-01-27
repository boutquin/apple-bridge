import Foundation

/// A note from Apple Notes.
///
/// Represents a single note with its content and metadata.
///
/// ## Example
/// ```swift
/// let note = Note(
///     id: "N123",
///     title: "Meeting Notes",
///     body: "Discussion points...",
///     folderId: "work",
///     modifiedAt: "2024-01-28T10:00:00Z"
/// )
/// ```
public struct Note: Codable, Sendable, Equatable {
    /// Unique identifier for the note.
    public let id: String

    /// Title of the note, if set.
    public let title: String?

    /// Body content of the note.
    public let body: String?

    /// Identifier of the folder containing this note.
    public let folderId: String?

    /// Last modification date/time in ISO 8601 format.
    public let modifiedAt: String

    /// Creates a new note.
    /// - Parameters:
    ///   - id: Unique identifier for the note.
    ///   - title: Title of the note.
    ///   - body: Body content.
    ///   - folderId: Identifier of the containing folder.
    ///   - modifiedAt: Last modification timestamp in ISO 8601 format.
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
