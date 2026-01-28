import Foundation
import MCP
import Core

/// MCP handlers for Messages domain tools.
///
/// Provides handlers for the 5 Messages tools:
/// - `messages_list_chats`: List all chat conversations
/// - `messages_read`: Read messages from a specific chat
/// - `messages_unread`: Get all unread messages
/// - `messages_send`: Send a message
/// - `messages_schedule`: Schedule a message for later
enum MessagesHandlers {

    // MARK: - messages_list_chats

    /// Lists all chat conversations.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: Optional limit parameter.
    /// - Returns: JSON array of chats with id and displayName.
    static func listChats(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 50

        do {
            let chats = try await services.messages.chats(limit: limit)

            // Convert to JSON-encodable format
            let response = chats.map { chat in
                ["id": chat.id, "displayName": chat.displayName]
            }

            return HandlerUtilities.successResult(response)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - messages_read

    /// Reads messages from a specific chat.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: chatId (required), limit (optional).
    /// - Returns: Paginated response with messages.
    static func readMessages(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let chatId = HandlerUtilities.extractString(from: arguments, key: "chatId") else {
            return HandlerUtilities.missingRequiredParameter("chatId")
        }

        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 50

        do {
            let page = try await services.messages.read(chatId: chatId, limit: limit)
            return HandlerUtilities.successResult(page)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - messages_unread

    /// Gets all unread messages.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: Optional limit parameter.
    /// - Returns: Array of unread messages.
    static func unreadMessages(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 50

        do {
            let messages = try await services.messages.unread(limit: limit)
            return HandlerUtilities.successResult(messages)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - messages_send

    /// Sends a message to a recipient.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: to (required), body (required).
    /// - Returns: Success confirmation with recipient.
    static func sendMessage(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let to = HandlerUtilities.extractString(from: arguments, key: "to") else {
            return HandlerUtilities.missingRequiredParameter("to")
        }

        guard let body = HandlerUtilities.extractString(from: arguments, key: "body") else {
            return HandlerUtilities.missingRequiredParameter("body")
        }

        do {
            try await services.messages.send(to: to, body: body)

            // Return success confirmation
            return CallTool.Result(
                content: [.text("{\"sent\": true, \"to\": \"\(to)\"}")],
                isError: false
            )
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - messages_schedule

    /// Schedules a message to be sent later.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: to (required), body (required), scheduledAt (required).
    /// - Returns: Success confirmation with scheduled time.
    static func scheduleMessage(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let to = HandlerUtilities.extractString(from: arguments, key: "to") else {
            return HandlerUtilities.missingRequiredParameter("to")
        }

        guard let body = HandlerUtilities.extractString(from: arguments, key: "body") else {
            return HandlerUtilities.missingRequiredParameter("body")
        }

        guard let scheduledAt = HandlerUtilities.extractString(from: arguments, key: "scheduledAt") else {
            return HandlerUtilities.missingRequiredParameter("scheduledAt")
        }

        do {
            try await services.messages.schedule(to: to, body: body, sendAt: scheduledAt)

            // Return success confirmation
            return CallTool.Result(
                content: [.text("{\"scheduled\": true, \"to\": \"\(to)\", \"scheduledAt\": \"\(scheduledAt)\"}")],
                isError: false
            )
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }
}
