import Testing
import Foundation
@testable import Core
import TestUtilities

@Suite("MailService Protocol Tests")
struct MailServiceTests {

    // MARK: - Protocol Conformance Tests

    @Test func testMockMailServiceConforms() async throws {
        let mock = MockMailService()
        let emails = try await mock.unread(limit: 10, includeBody: false)
        #expect(emails.isEmpty)
    }

    @Test func testMockMailServiceIsSendable() {
        let mock = MockMailService()
        Task { @Sendable in _ = mock }
    }

    // MARK: - Unread Emails Tests

    @Test func testUnreadEmailsWithStubData() async throws {
        let mock = MockMailService()
        await mock.setStubEmails([
            makeTestEmail(id: "E1", subject: "Unread 1", isUnread: true),
            makeTestEmail(id: "E2", subject: "Read", isUnread: false),
            makeTestEmail(id: "E3", subject: "Unread 2", isUnread: true)
        ])

        let emails = try await mock.unread(limit: 10, includeBody: false)
        #expect(emails.count == 2)
    }

    @Test func testUnreadEmailsIncludeBodyFalse() async throws {
        let mock = MockMailService()
        await mock.setStubEmails([
            makeTestEmail(id: "E1", body: "Body content", isUnread: true)
        ])

        let emails = try await mock.unread(limit: 10, includeBody: false)
        #expect(emails.count == 1)
        #expect(emails[0].body == nil)
    }

    @Test func testUnreadEmailsIncludeBodyTrue() async throws {
        let mock = MockMailService()
        await mock.setStubEmails([
            makeTestEmail(id: "E1", body: "Body content", isUnread: true)
        ])

        let emails = try await mock.unread(limit: 10, includeBody: true)
        #expect(emails.count == 1)
        #expect(emails[0].body == "Body content")
    }

    // MARK: - Search Emails Tests

    @Test func testSearchEmails() async throws {
        let mock = MockMailService()
        await mock.setStubEmails([
            makeTestEmail(id: "E1", subject: "Meeting tomorrow"),
            makeTestEmail(id: "E2", subject: "Lunch plans"),
            makeTestEmail(id: "E3", subject: "Meeting notes")
        ])

        let emails = try await mock.search(query: "Meeting", limit: 10, includeBody: false)
        #expect(emails.count == 2)
    }

    @Test func testSearchEmailsRespectsLimit() async throws {
        let mock = MockMailService()
        await mock.setStubEmails([
            makeTestEmail(id: "E1", subject: "Test 1"),
            makeTestEmail(id: "E2", subject: "Test 2"),
            makeTestEmail(id: "E3", subject: "Test 3")
        ])

        let emails = try await mock.search(query: "Test", limit: 2, includeBody: false)
        #expect(emails.count == 2)
    }

    // MARK: - Send Email Tests

    @Test func testSendEmail() async throws {
        let mock = MockMailService()

        try await mock.send(
            to: ["recipient@example.com"],
            subject: "Test Subject",
            body: "Test Body",
            cc: nil,
            bcc: nil
        )

        let sent = await mock.getSentEmails()
        #expect(sent.count == 1)
        #expect(sent[0].to == ["recipient@example.com"])
        #expect(sent[0].subject == "Test Subject")
    }

    @Test func testSendEmailWithCcBcc() async throws {
        let mock = MockMailService()

        try await mock.send(
            to: ["recipient@example.com"],
            subject: "Test",
            body: "Body",
            cc: ["cc@example.com"],
            bcc: ["bcc@example.com"]
        )

        let sent = await mock.getSentEmails()
        #expect(sent[0].cc == ["cc@example.com"])
        #expect(sent[0].bcc == ["bcc@example.com"])
    }

    // MARK: - Compose Email Tests

    @Test func testComposeEmail() async throws {
        let mock = MockMailService()

        try await mock.compose(to: ["test@example.com"], subject: "Draft", body: nil)

        let requests = await mock.getComposeRequests()
        #expect(requests.count == 1)
        #expect(requests[0].subject == "Draft")
    }
}
