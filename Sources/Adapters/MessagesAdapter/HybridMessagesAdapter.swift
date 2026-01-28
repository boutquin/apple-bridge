import Foundation
import Core

/// Hybrid SQLite+AppleScript implementation of `MessagesAdapterProtocol`.
///
/// Reads from the macOS Messages database at:
/// `~/Library/Messages/chat.db`
///
/// Requires Full Disk Access permission to read the Messages database.
/// Writing messages requires AppleScript via the Messages app.
///
/// ## Usage
/// ```swift
/// let adapter = HybridMessagesAdapter()
/// let chats = try await adapter.fetchChats(limit: 10)
/// let messages = try await adapter.fetchMessages(chatId: "chat-123", limit: 20)
/// ```
///
/// For testing, you can provide a custom database path:
/// ```swift
/// let adapter = HybridMessagesAdapter(dbPath: "/path/to/test-messages.sqlite")
/// ```
public struct HybridMessagesAdapter: MessagesAdapterProtocol, Sendable {

    /// Path to the SQLite database.
    private let dbPath: String

    /// Whether to open the database in read-only mode.
    private let readOnly: Bool

    /// The AppleScript runner to use for sending messages.
    private let runner: any AppleScriptRunnerProtocol

    // MARK: - Initialization

    /// Creates a new Messages adapter using the system Messages database.
    ///
    /// Uses the default path: `~/Library/Messages/chat.db`
    public init() {
        self.dbPath = PermissionChecks.messagesDatabasePath()
        self.readOnly = true
        self.runner = AppleScriptRunner.shared
    }

    /// Creates a new Messages adapter with a custom database path.
    ///
    /// Useful for testing with fixture databases.
    ///
    /// - Parameters:
    ///   - dbPath: Path to the SQLite database file.
    ///   - readOnly: Whether to open read-only. Defaults to `true`.
    ///   - runner: The AppleScript runner to use for sending. Defaults to shared runner.
    public init(dbPath: String, readOnly: Bool = true, runner: any AppleScriptRunnerProtocol = AppleScriptRunner.shared) {
        self.dbPath = dbPath
        self.readOnly = readOnly
        self.runner = runner
    }

    // MARK: - MessagesAdapterProtocol

    public func fetchChats(limit: Int) async throws -> [ChatData] {
        let db = try openDatabase()
        defer { db.close() }

        try validateSchema(db)

        let sql = """
            SELECT ROWID, chat_identifier, display_name
            FROM chat
            LIMIT ?
            """

        let results = try db.query(sql, parameters: [limit])

        return results.compactMap { row -> ChatData? in
            guard let rowid = row["ROWID"] as? Int64 else { return nil }

            // Use display_name if available, otherwise chat_identifier
            let displayName = (row["display_name"] as? String)
                ?? (row["chat_identifier"] as? String)
                ?? "Unknown"

            return ChatData(id: String(rowid), displayName: displayName)
        }
    }

    public func fetchMessages(chatId: String, limit: Int) async throws -> [MessageData] {
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
            return []
        }

        let results = try db.query(sql, parameters: [chatIdInt, limit])

        return results.compactMap { row -> MessageData? in
            rowToMessageData(row, chatId: chatId)
        }
    }

    public func fetchUnreadMessages(limit: Int) async throws -> [MessageData] {
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

        return results.compactMap { row -> MessageData? in
            guard let chatId = row["chat_id"] as? Int64 else { return nil }
            return rowToMessageData(row, chatId: String(chatId))
        }
    }

    public func sendMessage(to: String, body: String) async throws {
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

        _ = try await runner.run(script: script)
    }

    public func scheduleMessage(to: String, body: String, sendAt: String) async throws {
        // Messages.app doesn't support scheduled messages directly
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

    /// Converts a database row to a MessageData model.
    private func rowToMessageData(_ row: [String: Any?], chatId: String) -> MessageData? {
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

        return MessageData(
            id: id,
            chatId: chatId,
            sender: sender,
            date: date,
            body: body,
            isUnread: isUnread
        )
    }
}
