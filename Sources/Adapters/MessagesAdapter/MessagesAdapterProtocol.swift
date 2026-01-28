import Foundation
import Core

// MARK: - Messages Data Transfer Objects

/// Lightweight data representation of a message.
///
/// This struct provides a Sendable, Codable representation of messages
/// that can be safely passed across actor boundaries without requiring direct
/// framework access. Used as the boundary type between adapter implementations
/// (SQLite, AppleScript, etc.) and the service layer.
public struct MessageData: Sendable, Equatable, Codable {
    /// Unique identifier for the message.
    public let id: String

    /// Identifier of the chat containing this message.
    public let chatId: String

    /// Sender's identifier (phone number or email).
    public let sender: String

    /// Message timestamp in ISO 8601 format.
    public let date: String

    /// Message body content, if available.
    public let body: String?

    /// Whether this message is unread.
    public let isUnread: Bool

    /// Creates a new message data instance.
    /// - Parameters:
    ///   - id: Unique identifier for the message.
    ///   - chatId: Chat identifier containing this message.
    ///   - sender: Sender's identifier.
    ///   - date: Message timestamp in ISO 8601 format.
    ///   - body: Message body content.
    ///   - isUnread: Whether the message is unread.
    public init(
        id: String,
        chatId: String,
        sender: String,
        date: String,
        body: String? = nil,
        isUnread: Bool = false
    ) {
        self.id = id
        self.chatId = chatId
        self.sender = sender
        self.date = date
        self.body = body
        self.isUnread = isUnread
    }
}

/// Lightweight data representation of a chat (conversation).
///
/// This struct provides a Sendable representation of chats that can be
/// safely passed across actor boundaries. Used as the boundary type between
/// adapter implementations and the service layer.
public struct ChatData: Sendable, Equatable, Codable {
    /// Unique identifier for the chat.
    public let id: String

    /// Display name of the chat (contact name or phone number).
    public let displayName: String

    /// Creates a new chat data instance.
    /// - Parameters:
    ///   - id: Unique identifier for the chat.
    ///   - displayName: Display name of the chat.
    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

// MARK: - Protocol

/// Protocol for interacting with Apple Messages.
///
/// This protocol abstracts messages operations to enable testing with mock implementations
/// and to support multiple backend implementations (SQLite for reading, AppleScript for sending, etc.).
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Implementation Notes
/// - SQLite implementation reads directly from the Messages database (requires Full Disk Access)
/// - AppleScript implementation uses osascript for sending messages
/// - The protocol uses generic data transfer objects (MessageData, ChatData) to
///   decouple from specific implementation details
///
/// ## Example
/// ```swift
/// let adapter: MessagesAdapterProtocol = HybridMessagesAdapter()
/// let messages = try await adapter.fetchMessages(chatId: "chat-123", limit: 20)
/// ```
public protocol MessagesAdapterProtocol: Sendable {

    // MARK: - Chat Operations

    /// Fetches all chats (conversations).
    /// - Parameter limit: Maximum number of chats to return.
    /// - Returns: Array of chat data objects.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func fetchChats(limit: Int) async throws -> [ChatData]

    // MARK: - Message Operations

    /// Fetches messages from a specific chat.
    /// - Parameters:
    ///   - chatId: Identifier of the chat to read from.
    ///   - limit: Maximum number of messages to return.
    /// - Returns: Array of message data objects.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func fetchMessages(chatId: String, limit: Int) async throws -> [MessageData]

    /// Fetches all unread messages.
    /// - Parameter limit: Maximum number of messages to return.
    /// - Returns: Array of unread message data objects.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func fetchUnreadMessages(limit: Int) async throws -> [MessageData]

    // MARK: - Send Operations

    /// Sends a message to a recipient.
    /// - Parameters:
    ///   - to: Recipient phone number or email.
    ///   - body: Message content.
    /// - Throws: `AppleScriptError` if sending fails.
    func sendMessage(to: String, body: String) async throws

    /// Schedules a message to be sent later.
    /// - Parameters:
    ///   - to: Recipient phone number or email.
    ///   - body: Message content.
    ///   - sendAt: Scheduled send time in ISO 8601 format.
    /// - Throws: `AppleScriptError` if scheduling fails.
    func scheduleMessage(to: String, body: String, sendAt: String) async throws
}
