import Foundation
import Core

/// SQLite-based implementation of `NotesService`.
///
/// Reads from the macOS Notes database at:
/// `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`
///
/// Requires Full Disk Access permission to read the Notes database.
///
/// ## Usage
/// ```swift
/// let service = NotesSQLiteService()
/// let results = try await service.search(query: "meeting", limit: 10, includeBody: false)
/// ```
///
/// For testing, you can provide a custom database path:
/// ```swift
/// let service = NotesSQLiteService(dbPath: "/path/to/test-notes.sqlite")
/// ```
public struct NotesSQLiteService: NotesService, Sendable {

    /// Path to the SQLite database.
    private let dbPath: String

    /// Whether to open the database in read-only mode.
    private let readOnly: Bool

    // MARK: - Initialization

    /// Creates a new Notes service using the system Notes database.
    ///
    /// Uses the default path: `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`
    public init() {
        self.dbPath = PermissionChecks.notesDatabasePath()
        self.readOnly = true
    }

    /// Creates a new Notes service with a custom database path.
    ///
    /// Useful for testing with fixture databases.
    ///
    /// - Parameters:
    ///   - dbPath: Path to the SQLite database file.
    ///   - readOnly: Whether to open read-only. Defaults to `true`.
    public init(dbPath: String, readOnly: Bool = true) {
        self.dbPath = dbPath
        self.readOnly = readOnly
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
        let db = try openDatabase()
        defer { db.close() }

        try SchemaValidator.validateNotesSchema(db)

        // Build query - search in title and snippet
        let searchQuery = "%\(query)%"
        let sql: String
        let columns: String

        if includeBody {
            columns = "Z_PK, ZTITLE1, ZSNIPPET, ZMODIFICATIONDATE1, ZFOLDER"
        } else {
            columns = "Z_PK, ZTITLE1, NULL as ZSNIPPET, ZMODIFICATIONDATE1, ZFOLDER"
        }

        sql = """
            SELECT \(columns)
            FROM ZICCLOUDSYNCINGOBJECT
            WHERE (ZTITLE1 LIKE ? COLLATE NOCASE OR ZSNIPPET LIKE ? COLLATE NOCASE)
            ORDER BY ZMODIFICATIONDATE1 DESC
            LIMIT ?
            """

        let results = try db.query(sql, parameters: [searchQuery, searchQuery, limit])

        let notes = results.compactMap { row -> Note? in
            rowToNote(row, includeBody: includeBody)
        }

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
        let db = try openDatabase()
        defer { db.close() }

        try SchemaValidator.validateNotesSchema(db)

        // Parse the ID (which is the Z_PK primary key as a string)
        guard let pk = Int64(id) else {
            throw ValidationError.notFound(resource: "Note", id: id)
        }

        let sql = """
            SELECT Z_PK, ZTITLE1, ZSNIPPET, ZMODIFICATIONDATE1, ZFOLDER
            FROM ZICCLOUDSYNCINGOBJECT
            WHERE Z_PK = ?
            """

        let results = try db.query(sql, parameters: [pk])

        guard let row = results.first,
              let note = rowToNote(row, includeBody: true) else {
            throw ValidationError.notFound(resource: "Note", id: id)
        }

        return note
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
        // Open writable connection
        let db = try SQLiteConnection(path: dbPath, readOnly: false)
        defer { db.close() }

        try SchemaValidator.validateNotesSchema(db)

        // Current timestamp as Apple Core Data timestamp
        // Apple's reference date is January 1, 2001
        let appleEpoch = Date(timeIntervalSinceReferenceDate: 0) // Jan 1, 2001
        let now = Date()
        let timestamp = now.timeIntervalSince(appleEpoch)

        // Folder ID - use provided or default to 1
        let folder: Int64
        if let folderIdStr = folderId, let fid = Int64(folderIdStr) {
            // Validate folder exists
            let folderCheck = try db.query(
                "SELECT Z_PK FROM ZICCLOUDSYNCINGOBJECT WHERE Z_PK = ? AND ZFOLDER IS NULL",
                parameters: [fid]
            )
            if folderCheck.isEmpty {
                throw ValidationError.notFound(resource: "Folder", id: folderIdStr)
            }
            folder = fid
        } else {
            folder = 1 // Default folder
        }

        let sql = """
            INSERT INTO ZICCLOUDSYNCINGOBJECT (ZTITLE1, ZSNIPPET, ZMODIFICATIONDATE1, ZFOLDER)
            VALUES (?, ?, ?, ?)
            """

        _ = try db.query(sql, parameters: [title, body ?? "", timestamp, folder])

        // Get the last inserted row ID
        let lastIdResults = try db.query("SELECT last_insert_rowid() as id")
        guard let lastIdRow = lastIdResults.first,
              let lastId = lastIdRow["id"] as? Int64 else {
            throw ValidationError.missingRequired(field: "id")
        }

        return String(lastId)
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
        // First verify the note exists
        _ = try await get(id: id)

        // Open Notes app with the note
        // Use AppleScript to open the note by ID
        let script = """
            tell application "Notes"
                activate
            end tell
            """

        // TODO: Implement full note navigation using notes:// URL scheme or AppleScript
        // Currently only activates Notes.app without navigating to the specific note.
        // Full implementation would need to:
        // 1. Use `notes://showNote?identifier=<id>` URL scheme, OR
        // 2. Use AppleScript to select the note by its properties
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        try process.run()
        process.waitUntilExit()
    }

    // MARK: - Private Helpers

    /// Opens the database connection.
    private func openDatabase() throws -> SQLiteConnection {
        do {
            return try SQLiteConnection(path: dbPath, readOnly: readOnly)
        } catch let error as SQLiteError {
            // Check if this is a permission issue
            if case .databaseNotFound = error {
                // Check if it's actually a permission issue vs truly not found
                if !PermissionChecks.hasFullDiskAccess() {
                    throw PermissionError.fullDiskAccessDenied(context: "Notes")
                }
            }
            throw error
        }
    }

    /// Converts a database row to a Note model.
    private func rowToNote(_ row: [String: Any?], includeBody: Bool) -> Note? {
        guard let pk = row["Z_PK"] as? Int64 else {
            return nil
        }

        let id = String(pk)
        let title = row["ZTITLE1"] as? String
        let body: String?
        if includeBody {
            body = row["ZSNIPPET"] as? String
        } else {
            body = nil
        }
        let folderId = (row["ZFOLDER"] as? Int64).map { String($0) }

        // Convert Apple Core Data timestamp to ISO 8601
        let modifiedAt: String
        if let timestamp = row["ZMODIFICATIONDATE1"] as? Double {
            // Apple Core Data uses seconds since Jan 1, 2001
            let appleEpoch = Date(timeIntervalSinceReferenceDate: 0)
            let date = appleEpoch.addingTimeInterval(timestamp)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            modifiedAt = formatter.string(from: date)
        } else {
            // Fallback to current time
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            modifiedAt = formatter.string(from: Date())
        }

        return Note(
            id: id,
            title: title,
            body: body,
            folderId: folderId,
            modifiedAt: modifiedAt
        )
    }
}
