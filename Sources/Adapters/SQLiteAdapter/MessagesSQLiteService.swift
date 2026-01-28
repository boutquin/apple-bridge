import Foundation
import Core

/// SQLite-based implementation of `MessagesService`.
///
/// Reads from the macOS Messages database at:
/// `~/Library/Messages/chat.db`
///
/// Requires Full Disk Access permission to read the Messages database.
/// Writing messages requires AppleScript via the Messages app.
///
/// ## Usage
/// ```swift
/// let service = MessagesSQLiteService()
/// let chats = try await service.chats(limit: 10)
/// let messages = try await service.read(chatId: "chat-123", limit: 20)
/// ```
///
/// For testing, you can provide a custom database path:
/// ```swift
/// let service = MessagesSQLiteService(dbPath: "/path/to/test-messages.sqlite")
/// ```
public struct MessagesSQLiteService: MessagesService, Sendable {

    /// Path to the SQLite database.
    private let dbPath: String

    /// Whether to open the database in read-only mode.
    private let readOnly: Bool

    // MARK: - Initialization

    /// Creates a new Messages service using the system Messages database.
    ///
    /// Uses the default path: `~/Library/Messages/chat.db`
    public init() {
        self.dbPath = PermissionChecks.messagesDatabasePath()
        self.readOnly = true
    }

    /// Creates a new Messages service with a custom database path.
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

    // MARK: - MessagesService Protocol

    /// Retrieves messages from a specific chat.
    ///
    /// - Parameters:
    ///   - chatId: Identifier of the chat to read from.
    ///   - limit: Maximum number of messages to return.
    /// - Returns: A paginated response containing messages.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    /// - Throws: `SQLiteError` for database-related errors.
    public func read(chatId: String, limit: Int) async throws -> Page<Message> {
        let db = try openDatabase()
        defer { db.close() }

        try validateSchema(db)

        // Query messages for the specific chat
        // Messages date is in Apple's nanoseconds since 2001 format
        let sql = """
            SELECT m.ROWID as id, m.text, m.date, m.is_read, h.id as sender, c.ROWID as chat_id
            FROM message m
            JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
            JOIN chat c ON cmj.chat_id = c.ROWID
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE c.ROWID = ?
            ORDER BY m.date DESC
            LIMIT ?
            """

        guard let chatIdInt = Int64(chatId) else {
            // Invalid chat ID format - return empty
            return Page(items: [], nextCursor: nil, hasMore: false)
        }

        let results = try db.query(sql, parameters: [chatIdInt, limit])

        let messages = results.compactMap { row -> Message? in
            rowToMessage(row, chatId: chatId)
        }

        return Page(items: messages, nextCursor: nil, hasMore: false)
    }

    /// Retrieves all unread messages.
    ///
    /// - Parameter limit: Maximum number of messages to return.
    /// - Returns: Array of unread messages.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    /// - Throws: `SQLiteError` for database-related errors.
    public func unread(limit: Int) async throws -> [Message] {
        let db = try openDatabase()
        defer { db.close() }

        try validateSchema(db)

        // Query unread messages across all chats
        // is_read = 0 means unread
        let sql = """
            SELECT m.ROWID as id, m.text, m.date, m.is_read, h.id as sender, c.ROWID as chat_id
            FROM message m
            JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
            JOIN chat c ON cmj.chat_id = c.ROWID
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.is_read = 0
            ORDER BY m.date DESC
            LIMIT ?
            """

        let results = try db.query(sql, parameters: [limit])

        return results.compactMap { row -> Message? in
            guard let chatId = row["chat_id"] as? Int64 else { return nil }
            return rowToMessage(row, chatId: String(chatId))
        }
    }

    /// Lists all chats (conversations).
    ///
    /// - Parameter limit: Maximum number of chats to return.
    /// - Returns: Array of chat identifiers and display names.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    /// - Throws: `SQLiteError` for database-related errors.
    public func chats(limit: Int) async throws -> [(id: String, displayName: String)] {
        let db = try openDatabase()
        defer { db.close() }

        try validateSchema(db)

        let sql = """
            SELECT ROWID, chat_identifier, display_name
            FROM chat
            LIMIT ?
            """

        let results = try db.query(sql, parameters: [limit])

        return results.compactMap { row -> (id: String, displayName: String)? in
            guard let rowid = row["ROWID"] as? Int64 else { return nil }

            // Use display_name if available, otherwise chat_identifier
            let displayName = (row["display_name"] as? String)
                ?? (row["chat_identifier"] as? String)
                ?? "Unknown"

            return (id: String(rowid), displayName: displayName)
        }
    }

    /// Sends a message to a recipient.
    ///
    /// Uses AppleScript via `AppleScriptRunner` to send the message through Messages.app.
    /// The runner actor serializes concurrent sends to prevent race conditions.
    ///
    /// - Parameters:
    ///   - to: Recipient phone number or email.
    ///   - body: Message content.
    /// - Throws: `AppleScriptError` if sending fails.
    public func send(to: String, body: String) async throws {
        // Escape quotes in body and recipient for AppleScript
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedTo = to.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
            tell application "Messages"
                set targetService to 1st service whose service type = iMessage
                set targetBuddy to buddy "\(escapedTo)" of targetService
                send "\(escapedBody)" to targetBuddy
            end tell
            """

        _ = try await AppleScriptRunner.shared.run(script: script)
    }

    /// Schedules a message to be sent later.
    ///
    /// Note: Messages.app does not natively support scheduled messages.
    /// This method creates a reminder-based workaround or returns an error.
    ///
    /// - Parameters:
    ///   - to: Recipient phone number or email.
    ///   - body: Message content.
    ///   - sendAt: Scheduled send time in ISO 8601 format.
    /// - Throws: `AppleScriptError` if scheduling fails.
    public func schedule(to: String, body: String, sendAt: String) async throws {
        // Messages.app doesn't support scheduled messages directly
        // We could potentially create a reminder or use a background scheduler
        // For now, throw an error indicating this limitation
        throw AppleScriptError.executionFailed(
            message: "Scheduled messages are not supported. Messages.app does not have native scheduling support."
        )
    }

    // MARK: - Private Helpers

    /// Opens the database connection.
    private func openDatabase() throws -> SQLiteConnection {
        do {
            return try SQLiteConnection(path: dbPath, readOnly: readOnly)
        } catch let error as SQLiteError {
            // Check if this is a permission issue
            if case .databaseNotFound = error {
                if !PermissionChecks.hasFullDiskAccess() {
                    throw PermissionError.fullDiskAccessDenied(context: "Messages")
                }
            }
            throw error
        }
    }

    /// Validates that the database has the expected Messages schema.
    private func validateSchema(_ db: SQLiteConnection) throws {
        try SchemaValidator.validateMessagesSchema(db)
    }

    /// Converts a database row to a Message model.
    private func rowToMessage(_ row: [String: Any?], chatId: String) -> Message? {
        guard let rowid = row["id"] as? Int64 else {
            return nil
        }

        let id = String(rowid)
        let body = row["text"] as? String
        let sender = (row["sender"] as? String) ?? "Unknown"

        // is_read: 0 = unread, 1 = read
        let isReadValue = row["is_read"] as? Int64 ?? 1
        let isUnread = isReadValue == 0

        // Convert Apple Messages timestamp to ISO 8601
        // Messages uses nanoseconds since 2001-01-01 (with a factor of 1e9)
        let date: String
        if let timestamp = row["date"] as? Int64 {
            // Messages timestamp is in nanoseconds since 2001-01-01
            let seconds = Double(timestamp) / 1_000_000_000.0
            let appleEpoch = Date(timeIntervalSinceReferenceDate: 0) // Jan 1, 2001
            let messageDate = appleEpoch.addingTimeInterval(seconds)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.string(from: messageDate)
        } else {
            // Fallback to current time
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.string(from: Date())
        }

        return Message(
            id: id,
            chatId: chatId,
            sender: sender,
            date: date,
            body: body,
            isUnread: isUnread
        )
    }
}
