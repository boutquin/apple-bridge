import Testing
import Foundation
@testable import Core

@Suite("Email Tests")
struct EmailTests {
    @Test func testEmailRoundTrip() throws {
        let email = Email(
            id: "E1",
            subject: "Meeting Tomorrow",
            from: "sender@example.com",
            to: ["recipient@example.com", "cc@example.com"],
            date: "2026-01-27T10:00:00Z",
            body: "Let's meet at 2pm.",
            mailbox: "INBOX",
            isUnread: false
        )
        let json = try JSONEncoder().encode(email)
        let decoded = try JSONDecoder().decode(Email.self, from: json)
        #expect(decoded.id == "E1")
        #expect(decoded.subject == "Meeting Tomorrow")
        #expect(decoded.from == "sender@example.com")
        #expect(decoded.to == ["recipient@example.com", "cc@example.com"])
        #expect(decoded.date == "2026-01-27T10:00:00Z")
        #expect(decoded.body == "Let's meet at 2pm.")
        #expect(decoded.mailbox == "INBOX")
        #expect(decoded.isUnread == false)
    }

    @Test func testEmailWithNilOptionals() throws {
        let email = Email(
            id: "E2",
            subject: "Quick note",
            from: "sender@example.com",
            to: ["recipient@example.com"],
            date: "2026-01-27T10:00:00Z",
            body: nil,
            mailbox: nil,
            isUnread: true
        )
        let json = try JSONEncoder().encode(email)
        let decoded = try JSONDecoder().decode(Email.self, from: json)
        #expect(decoded.body == nil)
        #expect(decoded.mailbox == nil)
        #expect(decoded.isUnread == true)
    }

    @Test func testEmailMultipleRecipients() throws {
        let email = Email(
            id: "E3",
            subject: "Group email",
            from: "sender@example.com",
            to: ["a@example.com", "b@example.com", "c@example.com"],
            date: "2026-01-27T10:00:00Z",
            body: nil,
            mailbox: nil,
            isUnread: false
        )
        #expect(email.to.count == 3)
    }
}
