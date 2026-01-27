import Foundation

/// A message from Apple Messages (iMessage/SMS).
///
/// Represents a single message in a conversation with its sender,
/// timestamp, and read status.
///
/// ## Example
/// ```swift
/// let message = Message(
///     id: "M123",
///     chatId: "chat-456",
///     sender: "+1-555-0100",
///     date: "2024-01-28T10:00:00Z",
///     body: "Hello!",
///     isUnread: false
/// )
/// ```
public struct Message: Codable, Sendable, Equatable {
    /// Unique identifier for the message.
    public let id: String

    /// Identifier of the chat/conversation containing this message.
    public let chatId: String

    /// Sender of the message (phone number or email).
    public let sender: String

    /// Date/time the message was sent in ISO 8601 format.
    public let date: String

    /// Text content of the message.
    public let body: String?

    /// Whether the message has been read.
    public let isUnread: Bool

    /// Creates a new message.
    /// - Parameters:
    ///   - id: Unique identifier for the message.
    ///   - chatId: Identifier of the containing chat.
    ///   - sender: Sender's phone number or email.
    ///   - date: Send timestamp in ISO 8601 format.
    ///   - body: Text content of the message.
    ///   - isUnread: Whether the message is unread.
    public init(
        id: String,
        chatId: String,
        sender: String,
        date: String,
        body: String? = nil,
        isUnread: Bool
    ) {
        self.id = id
        self.chatId = chatId
        self.sender = sender
        self.date = date
        self.body = body
        self.isUnread = isUnread
    }
}
