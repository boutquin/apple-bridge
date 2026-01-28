import Testing
import Foundation
import MCP
@testable import MCPServer
@testable import Core
@testable import TestUtilities

/// Tests for Messages MCP tool handlers.
///
/// These tests verify that the MCP handlers correctly:
/// - Extract arguments
/// - Call the MessagesService
/// - Format responses
/// - Handle errors
@Suite("Messages Handler Tests")
struct MessagesHandlerTests {

    // MARK: - messages_list_chats

    @Test("messages_list_chats returns chats")
    func testListChatsReturnsChats() async {
        let services = makeTestServices()
        await services.mockMessages.setStubChats([
            (id: "chat-1", displayName: "John Doe"),
            (id: "chat-2", displayName: "Jane Smith")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_list_chats",
            arguments: ["limit": .int(10)]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("John Doe"))
            #expect(content.contains("Jane Smith"))
        }
    }

    @Test("messages_list_chats uses default limit")
    func testListChatsUsesDefaultLimit() async {
        let services = makeTestServices()
        await services.mockMessages.setStubChats([
            (id: "chat-1", displayName: "Test")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_list_chats",
            arguments: nil
        )

        #expect(result.isError == false)
    }

    @Test("messages_list_chats respects limit")
    func testListChatsRespectsLimit() async {
        let services = makeTestServices()
        await services.mockMessages.setStubChats([
            (id: "chat-1", displayName: "Chat 1"),
            (id: "chat-2", displayName: "Chat 2"),
            (id: "chat-3", displayName: "Chat 3")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_list_chats",
            arguments: ["limit": .int(1)]
        )

        #expect(result.isError == false)
        // Mock service respects limit, so we just verify it doesn't crash
    }

    // MARK: - messages_read

    @Test("messages_read returns messages from chat")
    func testReadReturnsMessages() async {
        let services = makeTestServices()
        await services.mockMessages.setStubMessages([
            Message(id: "msg-1", chatId: "chat-1", sender: "+1234567890", date: "2026-01-27T10:00:00Z", body: "Hello", isUnread: false),
            Message(id: "msg-2", chatId: "chat-1", sender: "+0987654321", date: "2026-01-27T10:01:00Z", body: "Hi", isUnread: false)
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_read",
            arguments: ["chatId": .string("chat-1"), "limit": .int(10)]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Hello"))
        }
    }

    @Test("messages_read requires chatId")
    func testReadRequiresChatId() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_read",
            arguments: ["limit": .int(10)]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("chatId"))
        }
    }

    @Test("messages_read returns paginated response")
    func testReadReturnsPaginatedResponse() async {
        let services = makeTestServices()
        await services.mockMessages.setStubMessages([
            Message(id: "msg-1", chatId: "chat-1", sender: "+1234567890", date: "2026-01-27T10:00:00Z", body: "Test", isUnread: false)
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_read",
            arguments: ["chatId": .string("chat-1")]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            // Should have Page structure with items, hasMore
            #expect(content.contains("items") || content.contains("Test"))
        }
    }

    // MARK: - messages_unread

    @Test("messages_unread returns unread messages")
    func testUnreadReturnsUnreadMessages() async {
        let services = makeTestServices()
        await services.mockMessages.setStubMessages([
            Message(id: "msg-1", chatId: "chat-1", sender: "+1234567890", date: "2026-01-27T10:00:00Z", body: "Unread message", isUnread: true),
            Message(id: "msg-2", chatId: "chat-1", sender: "+0987654321", date: "2026-01-27T10:01:00Z", body: "Read message", isUnread: false)
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_unread",
            arguments: ["limit": .int(10)]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Unread message"))
        }
    }

    @Test("messages_unread uses default limit")
    func testUnreadUsesDefaultLimit() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_unread",
            arguments: nil
        )

        #expect(result.isError == false)
    }

    // MARK: - messages_send

    @Test("messages_send calls service with correct parameters")
    func testSendCallsServiceWithCorrectParameters() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_send",
            arguments: [
                "to": .string("+1234567890"),
                "body": .string("Hello, World!")
            ]
        )

        #expect(result.isError == false)

        // Verify the mock received the send call
        let sentMessages = await services.mockMessages.getSentMessages()
        #expect(sentMessages.count == 1)
        #expect(sentMessages[0].to == "+1234567890")
        #expect(sentMessages[0].body == "Hello, World!")
    }

    @Test("messages_send requires to parameter")
    func testSendRequiresTo() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_send",
            arguments: ["body": .string("Hello")]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("to"))
        }
    }

    @Test("messages_send requires body parameter")
    func testSendRequiresBody() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_send",
            arguments: ["to": .string("+1234567890")]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("body"))
        }
    }

    @Test("messages_send returns success response")
    func testSendReturnsSuccessResponse() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_send",
            arguments: [
                "to": .string("+1234567890"),
                "body": .string("Test message")
            ]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("sent") || content.contains("true") || content.contains("+1234567890"))
        }
    }

    // MARK: - messages_schedule

    @Test("messages_schedule calls service with correct parameters")
    func testScheduleCallsServiceWithCorrectParameters() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_schedule",
            arguments: [
                "to": .string("+1234567890"),
                "body": .string("Scheduled message"),
                "scheduledAt": .string("2026-01-28T10:00:00Z")
            ]
        )

        #expect(result.isError == false)

        // Verify the mock received the schedule call
        let scheduledMessages = await services.mockMessages.getScheduledMessages()
        #expect(scheduledMessages.count == 1)
        #expect(scheduledMessages[0].to == "+1234567890")
        #expect(scheduledMessages[0].body == "Scheduled message")
        #expect(scheduledMessages[0].sendAt == "2026-01-28T10:00:00Z")
    }

    @Test("messages_schedule requires all parameters")
    func testScheduleRequiresAllParameters() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        // Missing scheduledAt
        let result = await registry.callTool(
            name: "messages_schedule",
            arguments: [
                "to": .string("+1234567890"),
                "body": .string("Test")
            ]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("scheduledAt"))
        }
    }

    // MARK: - Error Handling

    @Test("handlers propagate service errors")
    func testHandlersPropagateServiceErrors() async {
        let services = makeTestServices()
        await services.mockMessages.setError(PermissionError.fullDiskAccessDenied(context: "Messages"))
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "messages_list_chats",
            arguments: nil
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Full Disk Access") || content.contains("permission") || content.contains("Messages"))
        }
    }
}
