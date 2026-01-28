import Foundation
import Core

/// SQLite-based implementation of `MessagesService`.
///
/// Uses a `MessagesAdapterProtocol` to interact with the Messages database.
/// This enables dependency injection for testing.
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
/// For testing with a mock adapter:
/// ```swift
/// let adapter = MockMessagesAdapter()
/// let service = MessagesSQLiteService(adapter: adapter)
/// ```
public struct MessagesSQLiteService: MessagesService, Sendable {

    /// The adapter to use for messages operations.
    private let adapter: any MessagesAdapterProtocol

    // MARK: - Initialization

    /// Creates a new Messages service using the default adapter.
    ///
    /// Uses the default path: `~/Library/Messages/chat.db`
    public init() {
        self.adapter = HybridMessagesAdapter()
    }

    /// Creates a new Messages service with a custom adapter (for testing).
    ///
    /// - Parameter adapter: The messages adapter to use.
    public init(adapter: any MessagesAdapterProtocol) {
        self.adapter = adapter
    }

    /// Creates a new Messages service with a custom database path (for backward compatibility).
    ///
    /// Useful for testing with fixture databases.
    ///
    /// - Parameters:
    ///   - dbPath: Path to the SQLite database file.
    ///   - readOnly: Whether to open read-only. Defaults to `true`.
    public init(dbPath: String, readOnly: Bool = true) {
        self.adapter = HybridMessagesAdapter(dbPath: dbPath, readOnly: readOnly)
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
        let messageData = try await adapter.fetchMessages(chatId: chatId, limit: limit)
        let messages = messageData.map { toMessage($0) }
        return Page(items: messages, nextCursor: nil, hasMore: false)
    }

    /// Retrieves all unread messages.
    ///
    /// - Parameter limit: Maximum number of messages to return.
    /// - Returns: Array of unread messages.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    /// - Throws: `SQLiteError` for database-related errors.
    public func unread(limit: Int) async throws -> [Message] {
        let messageData = try await adapter.fetchUnreadMessages(limit: limit)
        return messageData.map { toMessage($0) }
    }

    /// Lists all chats (conversations).
    ///
    /// - Parameter limit: Maximum number of chats to return.
    /// - Returns: Array of chat identifiers and display names.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    /// - Throws: `SQLiteError` for database-related errors.
    public func chats(limit: Int) async throws -> [(id: String, displayName: String)] {
        let chatData = try await adapter.fetchChats(limit: limit)
        return chatData.map { (id: $0.id, displayName: $0.displayName) }
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
        try await adapter.sendMessage(to: to, body: body)
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
        try await adapter.scheduleMessage(to: to, body: body, sendAt: sendAt)
    }

    // MARK: - Private Helpers

    /// Converts MessageData to Message model.
    private func toMessage(_ data: MessageData) -> Message {
        Message(
            id: data.id,
            chatId: data.chatId,
            sender: data.sender,
            date: data.date,
            body: data.body,
            isUnread: data.isUnread
        )
    }
}
