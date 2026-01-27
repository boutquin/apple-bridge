import Testing
import Foundation
@testable import Core

@Suite("Message Tests")
struct MessageTests {
    @Test func testMessageRoundTrip() throws {
        let message = Message(
            id: "M1",
            chatId: "chat-1",
            sender: "+1234567890",
            date: "2026-01-27T10:00:00Z",
            body: "Hello, how are you?",
            isUnread: false
        )
        let json = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: json)
        #expect(decoded.id == "M1")
        #expect(decoded.chatId == "chat-1")
        #expect(decoded.sender == "+1234567890")
        #expect(decoded.date == "2026-01-27T10:00:00Z")
        #expect(decoded.body == "Hello, how are you?")
        #expect(decoded.isUnread == false)
    }

    @Test func testMessageWithNilBody() throws {
        let message = Message(
            id: "M2",
            chatId: "chat-1",
            sender: "+1234567890",
            date: "2026-01-27T10:00:00Z",
            body: nil,
            isUnread: true
        )
        let json = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: json)
        #expect(decoded.body == nil)
        #expect(decoded.isUnread == true)
    }

    @Test func testMessageIsUnreadField() throws {
        let unreadMessage = Message(id: "M1", chatId: "c1", sender: "s", date: "d", body: nil, isUnread: true)
        let readMessage = Message(id: "M2", chatId: "c1", sender: "s", date: "d", body: nil, isUnread: false)
        #expect(unreadMessage.isUnread == true)
        #expect(readMessage.isUnread == false)
    }
}
