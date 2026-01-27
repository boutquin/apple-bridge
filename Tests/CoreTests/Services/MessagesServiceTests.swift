import Testing
import Foundation
@testable import Core
import TestUtilities

@Suite("MessagesService Protocol Tests")
struct MessagesServiceTests {

    // MARK: - Protocol Conformance Tests

    @Test func testMockMessagesServiceConforms() async throws {
        let mock = MockMessagesService()
        let page = try await mock.read(chatId: "test", limit: 10)
        #expect(page.items.isEmpty)
    }

    @Test func testMockMessagesServiceIsSendable() {
        let mock = MockMessagesService()
        Task { @Sendable in _ = mock }
    }

    // MARK: - Read Messages Tests

    @Test func testReadMessagesWithStubData() async throws {
        let mock = MockMessagesService()
        await mock.setStubMessages([
            makeTestMessage(id: "M1", chatId: "chat-1", body: "Hello"),
            makeTestMessage(id: "M2", chatId: "chat-1", body: "World"),
            makeTestMessage(id: "M3", chatId: "chat-2", body: "Other")
        ])

        let page = try await mock.read(chatId: "chat-1", limit: 10)
        #expect(page.items.count == 2)
    }

    @Test func testReadMessagesRespectsLimit() async throws {
        let mock = MockMessagesService()
        await mock.setStubMessages([
            makeTestMessage(id: "M1", chatId: "chat-1"),
            makeTestMessage(id: "M2", chatId: "chat-1"),
            makeTestMessage(id: "M3", chatId: "chat-1")
        ])

        let page = try await mock.read(chatId: "chat-1", limit: 2)
        #expect(page.items.count == 2)
        #expect(page.hasMore == true)
    }

    // MARK: - Unread Messages Tests

    @Test func testUnreadMessages() async throws {
        let mock = MockMessagesService()
        await mock.setStubMessages([
            makeTestMessage(id: "M1", isUnread: true),
            makeTestMessage(id: "M2", isUnread: false),
            makeTestMessage(id: "M3", isUnread: true)
        ])

        let unread = try await mock.unread(limit: 10)
        #expect(unread.count == 2)
    }

    // MARK: - Chats Tests

    @Test func testListChats() async throws {
        let mock = MockMessagesService()
        await mock.setStubChats([
            (id: "chat-1", displayName: "John"),
            (id: "chat-2", displayName: "Jane")
        ])

        let chats = try await mock.chats(limit: 10)
        #expect(chats.count == 2)
    }

    // MARK: - Send Message Tests

    @Test func testSendMessage() async throws {
        let mock = MockMessagesService()

        try await mock.send(to: "+1234567890", body: "Test message")

        let sent = await mock.getSentMessages()
        #expect(sent.count == 1)
        #expect(sent[0].to == "+1234567890")
        #expect(sent[0].body == "Test message")
    }

    // MARK: - Schedule Message Tests

    @Test func testScheduleMessage() async throws {
        let mock = MockMessagesService()

        try await mock.schedule(to: "+1234567890", body: "Scheduled", sendAt: "2026-01-28T10:00:00Z")

        let scheduled = await mock.getScheduledMessages()
        #expect(scheduled.count == 1)
        #expect(scheduled[0].sendAt == "2026-01-28T10:00:00Z")
    }
}
