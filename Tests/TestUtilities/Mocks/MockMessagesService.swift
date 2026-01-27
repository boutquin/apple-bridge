import Foundation
import Core

/// Mock implementation of `MessagesService` for testing.
public actor MockMessagesService: MessagesService {

    /// Stubbed messages to return from read operations.
    public var stubMessages: [Message] = []

    /// Stubbed chats to return.
    public var stubChats: [(id: String, displayName: String)] = []

    /// Tracks messages that have been sent.
    public var sentMessages: [(to: String, body: String)] = []

    /// Tracks scheduled messages.
    public var scheduledMessages: [(to: String, body: String, sendAt: String)] = []

    /// Error to throw (if set) for testing error scenarios.
    public var errorToThrow: (any Error)?

    /// Creates a new mock messages service.
    public init() {}

    /// Sets stubbed messages for testing.
    public func setStubMessages(_ messages: [Message]) {
        self.stubMessages = messages
    }

    /// Sets stubbed chats for testing.
    public func setStubChats(_ chats: [(id: String, displayName: String)]) {
        self.stubChats = chats
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    /// Gets sent messages for verification.
    public func getSentMessages() -> [(to: String, body: String)] {
        return sentMessages
    }

    /// Gets scheduled messages for verification.
    public func getScheduledMessages() -> [(to: String, body: String, sendAt: String)] {
        return scheduledMessages
    }

    public func read(chatId: String, limit: Int) async throws -> Page<Message> {
        if let error = errorToThrow { throw error }

        let filtered = stubMessages.filter { $0.chatId == chatId }
        let limitedMessages = Array(filtered.prefix(limit))
        let hasMore = filtered.count > limit
        let nextCursor = hasMore ? "mock-cursor-\(limit)" : nil

        return Page(items: limitedMessages, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func unread(limit: Int) async throws -> [Message] {
        if let error = errorToThrow { throw error }

        let filtered = stubMessages.filter { $0.isUnread }
        return Array(filtered.prefix(limit))
    }

    public func chats(limit: Int) async throws -> [(id: String, displayName: String)] {
        if let error = errorToThrow { throw error }
        return Array(stubChats.prefix(limit))
    }

    public func send(to: String, body: String) async throws {
        if let error = errorToThrow { throw error }
        sentMessages.append((to: to, body: body))
    }

    public func schedule(to: String, body: String, sendAt: String) async throws {
        if let error = errorToThrow { throw error }
        scheduledMessages.append((to: to, body: body, sendAt: sendAt))
    }
}
