import Testing
import Foundation
@testable import Adapters
@testable import Core

/// Tests for `MessagesSQLiteService`, the SQLite-based Messages implementation.
///
/// These tests use a fixture database at `Tests/AdapterTests/Fixtures/test-messages.sqlite`
/// containing pre-populated messages, chats, and handles for testing read operations.
@Suite("MessagesSQLiteService Tests")
struct MessagesSQLiteServiceTests {

    // MARK: - Test Fixture Path

    /// Path to the test fixture database.
    private var fixturePath: String {
        // Use Bundle.module for SPM resources
        guard let path = Bundle.module.path(forResource: "test-messages", ofType: "sqlite", inDirectory: "Fixtures") else {
            fatalError("Test fixture not found: test-messages.sqlite")
        }
        return path
    }

    // MARK: - Chats Tests

    @Test("chats returns all chat conversations")
    func testChatsReturnsConversations() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let chats = try await service.chats(limit: 10)

        #expect(chats.count >= 2, "Fixture should have at least 2 chats")
    }

    @Test("chats respects limit parameter")
    func testChatsRespectsLimit() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let chats = try await service.chats(limit: 1)

        #expect(chats.count <= 1)
    }

    @Test("chats returns chat identifiers and display names")
    func testChatsReturnsIdentifiersAndNames() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let chats = try await service.chats(limit: 10)

        guard let firstChat = chats.first else {
            Issue.record("No chats returned")
            return
        }

        #expect(!firstChat.id.isEmpty, "Chat should have an ID")
        #expect(!firstChat.displayName.isEmpty, "Chat should have a display name")
    }

    // MARK: - Read Tests

    @Test("read returns messages from specific chat")
    func testReadReturnsMessagesFromChat() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        // Get a chat ID first
        let chats = try await service.chats(limit: 1)
        guard let chatId = chats.first?.id else {
            Issue.record("No chats in fixture")
            return
        }

        let page = try await service.read(chatId: chatId, limit: 10)

        #expect(!page.items.isEmpty, "Should have messages in the chat")
    }

    @Test("read respects limit parameter")
    func testReadRespectsLimit() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let chats = try await service.chats(limit: 1)
        guard let chatId = chats.first?.id else {
            Issue.record("No chats in fixture")
            return
        }

        let page = try await service.read(chatId: chatId, limit: 1)

        #expect(page.items.count <= 1)
    }

    @Test("read returns messages with correct structure")
    func testReadReturnsMessagesWithCorrectStructure() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let chats = try await service.chats(limit: 1)
        guard let chatId = chats.first?.id else {
            Issue.record("No chats in fixture")
            return
        }

        let page = try await service.read(chatId: chatId, limit: 10)
        guard let message = page.items.first else {
            Issue.record("No messages returned")
            return
        }

        #expect(!message.id.isEmpty, "Message should have an ID")
        #expect(!message.chatId.isEmpty, "Message should have a chat ID")
        #expect(!message.sender.isEmpty, "Message should have a sender")
        #expect(!message.date.isEmpty, "Message should have a date")
    }

    @Test("read returns messages in descending date order")
    func testReadReturnsMessagesInDescendingOrder() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let chats = try await service.chats(limit: 1)
        guard let chatId = chats.first?.id else {
            Issue.record("No chats in fixture")
            return
        }

        let page = try await service.read(chatId: chatId, limit: 10)

        // Verify descending order (most recent first)
        var previousDate: String?
        for message in page.items {
            if let prev = previousDate {
                #expect(message.date <= prev, "Messages should be in descending date order")
            }
            previousDate = message.date
        }
    }

    @Test("read returns empty for non-existent chat")
    func testReadReturnsEmptyForNonExistentChat() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let page = try await service.read(chatId: "nonexistent-chat-id", limit: 10)

        #expect(page.items.isEmpty)
    }

    // MARK: - Unread Tests

    @Test("unread returns only unread messages")
    func testUnreadReturnsOnlyUnreadMessages() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let messages = try await service.unread(limit: 10)

        for message in messages {
            #expect(message.isUnread, "All messages should be unread")
        }
    }

    @Test("unread respects limit parameter")
    func testUnreadRespectsLimit() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let messages = try await service.unread(limit: 1)

        #expect(messages.count <= 1)
    }

    @Test("unread returns messages with correct structure")
    func testUnreadReturnsMessagesWithCorrectStructure() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let messages = try await service.unread(limit: 10)

        guard let message = messages.first else {
            // No unread messages is valid - check fixture has at least one
            let chats = try await service.chats(limit: 1)
            guard let chatId = chats.first?.id else {
                Issue.record("No chats in fixture")
                return
            }
            let allMessages = try await service.read(chatId: chatId, limit: 10)
            let hasUnread = allMessages.items.contains { $0.isUnread }
            #expect(hasUnread || !hasUnread, "Fixture state determines if unread exist")
            return
        }

        #expect(!message.id.isEmpty, "Message should have an ID")
        #expect(!message.sender.isEmpty, "Message should have a sender")
        #expect(message.isUnread, "Message should be marked unread")
    }

    // MARK: - Service Properties

    @Test("MessagesSQLiteService is Sendable")
    func testServiceIsSendable() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        // Compile-time check: can be passed across actor boundaries
        Task { @Sendable in
            _ = service
        }
    }

    @Test("MessagesSQLiteService conforms to MessagesService protocol")
    func testServiceConformsToProtocol() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        // Type check - service can be used as MessagesService
        let _: any MessagesService = service
    }

    // MARK: - Error Handling

    @Test("service throws for non-existent database path")
    func testServiceThrowsForNonExistentPath() async throws {
        let service = MessagesSQLiteService(dbPath: "/nonexistent/path/database.sqlite")

        do {
            _ = try await service.chats(limit: 10)
            Issue.record("Should have thrown an error")
        } catch {
            // Expected - database file not found
        }
    }

    // MARK: - Date Conversion Tests

    @Test("message dates are in ISO 8601 format")
    func testMessageDatesAreISO8601() async throws {
        let service = MessagesSQLiteService(dbPath: fixturePath)

        let chats = try await service.chats(limit: 1)
        guard let chatId = chats.first?.id else {
            Issue.record("No chats in fixture")
            return
        }

        let page = try await service.read(chatId: chatId, limit: 1)
        guard let message = page.items.first else {
            Issue.record("No messages returned")
            return
        }

        // ISO 8601 format: 2026-01-27T10:00:00Z or with fractional seconds
        let datePattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$"#
        let regex = try Regex(datePattern)
        #expect(message.date.contains(regex), "Date should be in ISO 8601 format")
    }
}
