import Foundation
import Core
import Adapters

/// Mock implementation of `MessagesAdapterProtocol` for testing.
///
/// Provides stubbed data and tracks method calls for verification in tests.
/// All methods are actor-isolated for thread safety.
public actor MockMessagesAdapter: MessagesAdapterProtocol {

    // MARK: - Stub Data

    /// Stubbed chats to return.
    private var stubChats: [ChatData] = []

    /// Stubbed messages to return.
    private var stubMessages: [MessageData] = []

    /// Error to throw (if set) for testing error scenarios.
    private var errorToThrow: (any Error)?

    // MARK: - Tracking

    /// Tracks fetch chat requests.
    private var fetchChatsRequests: [Int] = []

    /// Tracks fetch messages requests.
    private var fetchMessagesRequests: [(chatId: String, limit: Int)] = []

    /// Tracks fetch unread messages requests.
    private var fetchUnreadRequests: [Int] = []

    /// Tracks sent messages.
    private var sentMessages: [(to: String, body: String)] = []

    /// Tracks scheduled messages.
    private var scheduledMessages: [(to: String, body: String, sendAt: String)] = []

    // MARK: - Initialization

    /// Creates a new mock messages adapter.
    public init() {}

    // MARK: - Setup Methods

    /// Sets stubbed chats for testing.
    public func setStubChats(_ chats: [ChatData]) {
        self.stubChats = chats
    }

    /// Sets stubbed messages for testing.
    public func setStubMessages(_ messages: [MessageData]) {
        self.stubMessages = messages
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    // MARK: - Verification Methods

    /// Gets the fetch chats requests for verification.
    public func getFetchChatsRequests() -> [Int] {
        return fetchChatsRequests
    }

    /// Gets the fetch messages requests for verification.
    public func getFetchMessagesRequests() -> [(chatId: String, limit: Int)] {
        return fetchMessagesRequests
    }

    /// Gets the fetch unread requests for verification.
    public func getFetchUnreadRequests() -> [Int] {
        return fetchUnreadRequests
    }

    /// Gets the sent messages for verification.
    public func getSentMessages() -> [(to: String, body: String)] {
        return sentMessages
    }

    /// Gets the scheduled messages for verification.
    public func getScheduledMessages() -> [(to: String, body: String, sendAt: String)] {
        return scheduledMessages
    }

    // MARK: - MessagesAdapterProtocol

    public func fetchChats(limit: Int) async throws -> [ChatData] {
        if let error = errorToThrow { throw error }
        fetchChatsRequests.append(limit)
        return Array(stubChats.prefix(limit))
    }

    public func fetchMessages(chatId: String, limit: Int) async throws -> [MessageData] {
        if let error = errorToThrow { throw error }
        fetchMessagesRequests.append((chatId: chatId, limit: limit))

        let filtered = stubMessages.filter { $0.chatId == chatId }
        return Array(filtered.prefix(limit))
    }

    public func fetchUnreadMessages(limit: Int) async throws -> [MessageData] {
        if let error = errorToThrow { throw error }
        fetchUnreadRequests.append(limit)

        let unread = stubMessages.filter { $0.isUnread }
        return Array(unread.prefix(limit))
    }

    public func sendMessage(to: String, body: String) async throws {
        if let error = errorToThrow { throw error }
        sentMessages.append((to: to, body: body))
    }

    public func scheduleMessage(to: String, body: String, sendAt: String) async throws {
        if let error = errorToThrow { throw error }
        scheduledMessages.append((to: to, body: body, sendAt: sendAt))
    }
}
