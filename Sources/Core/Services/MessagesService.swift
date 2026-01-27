import Foundation

/// Protocol for interacting with Apple Messages.
///
/// Defines operations for reading and sending messages.
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Example
/// ```swift
/// let service: MessagesService = MessagesSQLiteService()
/// let messages = try await service.read(chatId: "chat-123", limit: 10)
/// ```
public protocol MessagesService: Sendable {

    /// Retrieves messages from a specific chat.
    /// - Parameters:
    ///   - chatId: Identifier of the chat to read from.
    ///   - limit: Maximum number of messages to return.
    /// - Returns: A paginated response containing messages.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func read(chatId: String, limit: Int) async throws -> Page<Message>

    /// Retrieves all unread messages.
    /// - Parameter limit: Maximum number of messages to return.
    /// - Returns: Array of unread messages.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func unread(limit: Int) async throws -> [Message]

    /// Lists all chats (conversations).
    /// - Parameter limit: Maximum number of chats to return.
    /// - Returns: Array of chat identifiers and display names.
    /// - Throws: `PermissionError.fullDiskAccessDenied` if FDA is not granted.
    func chats(limit: Int) async throws -> [(id: String, displayName: String)]

    /// Sends a message to a recipient.
    /// - Parameters:
    ///   - to: Recipient phone number or email.
    ///   - body: Message content.
    /// - Throws: `AppleScriptError` if sending fails.
    func send(to: String, body: String) async throws

    /// Schedules a message to be sent later.
    /// - Parameters:
    ///   - to: Recipient phone number or email.
    ///   - body: Message content.
    ///   - sendAt: Scheduled send time in ISO 8601 format.
    /// - Throws: `AppleScriptError` if scheduling fails.
    func schedule(to: String, body: String, sendAt: String) async throws
}
