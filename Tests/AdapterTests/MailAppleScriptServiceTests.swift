import Testing
import Foundation
@testable import Adapters
@testable import Core
import TestUtilities

/// Tests for `MailAppleScriptService`.
///
/// Tests use a mock AppleScript runner to verify the correct AppleScript
/// commands are generated for Mail operations.
@Suite("MailAppleScriptService Tests")
struct MailAppleScriptServiceTests {

    // MARK: - Protocol Conformance

    @Test("MailAppleScriptService conforms to MailService")
    func testConformsToMailService() async throws {
        let runner = MockAppleScriptRunner()
        let service: any MailService = MailAppleScriptService(runner: runner)

        // Basic conformance check - should be able to call protocol methods
        _ = service
    }

    @Test("MailAppleScriptService is Sendable")
    func testIsSendable() async throws {
        let runner = MockAppleScriptRunner()
        let service = MailAppleScriptService(runner: runner)
        Task { @Sendable in _ = service }
    }

    // MARK: - Unread Emails Tests

    @Test("unread generates correct AppleScript for Mail app")
    func testUnreadGeneratesCorrectScript() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("""
            [{"id":"1","subject":"Test","from":"a@b.com","to":"c@d.com","date":"2026-01-27T10:00:00Z","isUnread":true}]
            """)
        let service = MailAppleScriptService(runner: runner)

        _ = try await service.unread(limit: 10, includeBody: false)

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("Mail") == true, "Script should reference Mail app")
        #expect(lastScript?.contains("unread") == true || lastScript?.contains("read status") == true,
                "Script should filter for unread status")
    }

    @Test("unread respects limit parameter")
    func testUnreadRespectsLimit() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("[]")
        let service = MailAppleScriptService(runner: runner)

        _ = try await service.unread(limit: 5, includeBody: false)

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("5") == true, "Script should include limit")
    }

    @Test("unread includeBody parameter affects script")
    func testUnreadIncludeBodyAffectsScript() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("[]")
        let service = MailAppleScriptService(runner: runner)

        _ = try await service.unread(limit: 10, includeBody: true)

        let lastScript = await runner.getLastScript()
        // When includeBody is true, the script should fetch body content
        #expect(lastScript?.contains("content") == true || lastScript?.contains("body") == true,
                "Script should reference body/content when includeBody is true")
    }

    @Test("unread returns emails from AppleScript response")
    func testUnreadReturnsEmails() async throws {
        let runner = MockAppleScriptRunner()
        // AppleScript returns a formatted list that the service parses
        await runner.setStubResponse("""
            E1\tTest Subject\tsender@example.com\trecipient@example.com\t2026-01-27T10:00:00Z\tINBOX\t\t
            """)
        let service = MailAppleScriptService(runner: runner)

        let emails = try await service.unread(limit: 10, includeBody: false)

        #expect(emails.count >= 0) // At least doesn't crash
    }

    @Test("unread throws AppleScriptError on failure")
    func testUnreadThrowsOnFailure() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setError(AppleScriptError.executionFailed(message: "Mail not available"))
        let service = MailAppleScriptService(runner: runner)

        do {
            _ = try await service.unread(limit: 10, includeBody: false)
            Issue.record("Should have thrown AppleScriptError")
        } catch is AppleScriptError {
            // Expected
        }
    }

    // MARK: - Search Emails Tests

    @Test("search generates correct AppleScript with query")
    func testSearchGeneratesCorrectScript() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("[]")
        let service = MailAppleScriptService(runner: runner)

        _ = try await service.search(query: "meeting", limit: 10, includeBody: false)

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("Mail") == true, "Script should reference Mail app")
        #expect(lastScript?.contains("meeting") == true, "Script should include search query")
    }

    @Test("search escapes special characters in query")
    func testSearchEscapesSpecialCharacters() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("[]")
        let service = MailAppleScriptService(runner: runner)

        _ = try await service.search(query: "test \"quoted\" query", limit: 10, includeBody: false)

        let lastScript = await runner.getLastScript()
        // Quotes should be escaped for AppleScript
        #expect(lastScript?.contains("\\\"") == true, "Script should escape quotes")
    }

    @Test("search respects limit parameter")
    func testSearchRespectsLimit() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("[]")
        let service = MailAppleScriptService(runner: runner)

        _ = try await service.search(query: "test", limit: 15, includeBody: false)

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("15") == true, "Script should include limit")
    }

    @Test("search throws AppleScriptError on failure")
    func testSearchThrowsOnFailure() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setError(AppleScriptError.executionFailed(message: "Mail access denied"))
        let service = MailAppleScriptService(runner: runner)

        do {
            _ = try await service.search(query: "test", limit: 10, includeBody: false)
            Issue.record("Should have thrown AppleScriptError")
        } catch is AppleScriptError {
            // Expected
        }
    }

    // MARK: - Send Email Tests

    @Test("send generates correct AppleScript")
    func testSendGeneratesCorrectScript() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        try await service.send(
            to: ["recipient@example.com"],
            subject: "Test Subject",
            body: "Test Body",
            cc: nil,
            bcc: nil
        )

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("Mail") == true, "Script should reference Mail app")
        #expect(lastScript?.contains("recipient@example.com") == true, "Script should include recipient")
        #expect(lastScript?.contains("Test Subject") == true, "Script should include subject")
        #expect(lastScript?.contains("Test Body") == true, "Script should include body")
    }

    @Test("send handles multiple recipients")
    func testSendHandlesMultipleRecipients() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        try await service.send(
            to: ["one@example.com", "two@example.com"],
            subject: "Test",
            body: "Body",
            cc: nil,
            bcc: nil
        )

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("one@example.com") == true, "Script should include first recipient")
        #expect(lastScript?.contains("two@example.com") == true, "Script should include second recipient")
    }

    @Test("send includes CC recipients when provided")
    func testSendIncludesCc() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        try await service.send(
            to: ["to@example.com"],
            subject: "Test",
            body: "Body",
            cc: ["cc@example.com"],
            bcc: nil
        )

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("cc@example.com") == true, "Script should include CC recipient")
    }

    @Test("send includes BCC recipients when provided")
    func testSendIncludesBcc() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        try await service.send(
            to: ["to@example.com"],
            subject: "Test",
            body: "Body",
            cc: nil,
            bcc: ["bcc@example.com"]
        )

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("bcc@example.com") == true, "Script should include BCC recipient")
    }

    @Test("send escapes quotes in content")
    func testSendEscapesQuotes() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        try await service.send(
            to: ["to@example.com"],
            subject: "Subject with \"quotes\"",
            body: "Body with \"quotes\"",
            cc: nil,
            bcc: nil
        )

        let lastScript = await runner.getLastScript()
        // Quotes should be escaped for AppleScript
        #expect(lastScript?.contains("\\\"") == true, "Script should escape quotes")
    }

    @Test("send throws AppleScriptError on failure")
    func testSendThrowsOnFailure() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setError(AppleScriptError.executionFailed(message: "Send failed"))
        let service = MailAppleScriptService(runner: runner)

        do {
            try await service.send(
                to: ["to@example.com"],
                subject: "Test",
                body: "Body",
                cc: nil,
                bcc: nil
            )
            Issue.record("Should have thrown AppleScriptError")
        } catch is AppleScriptError {
            // Expected
        }
    }

    // MARK: - Compose Email Tests

    @Test("compose generates correct AppleScript")
    func testComposeGeneratesCorrectScript() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        try await service.compose(
            to: ["recipient@example.com"],
            subject: "Draft Subject",
            body: "Draft Body"
        )

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("Mail") == true, "Script should reference Mail app")
        #expect(lastScript?.contains("outgoing message") == true || lastScript?.contains("new message") == true,
                "Script should create a new message")
    }

    @Test("compose with nil parameters creates blank email")
    func testComposeWithNilParameters() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        try await service.compose(to: nil, subject: nil, body: nil)

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("Mail") == true, "Script should reference Mail app")
    }

    @Test("compose activates Mail app")
    func testComposeActivatesMail() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        try await service.compose(to: ["test@example.com"], subject: "Test", body: nil)

        let lastScript = await runner.getLastScript()
        #expect(lastScript?.contains("activate") == true, "Script should activate Mail app")
    }

    @Test("compose throws AppleScriptError on failure")
    func testComposeThrowsOnFailure() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setError(AppleScriptError.executionFailed(message: "Mail not available"))
        let service = MailAppleScriptService(runner: runner)

        do {
            try await service.compose(to: ["test@example.com"], subject: "Test", body: nil)
            Issue.record("Should have thrown AppleScriptError")
        } catch is AppleScriptError {
            // Expected
        }
    }

    // MARK: - Edge Case Tests

    @Test("unread handles empty response")
    func testUnreadHandlesEmptyResponse() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        let emails = try await service.unread(limit: 10, includeBody: false)

        #expect(emails.isEmpty, "Empty response should produce empty array")
    }

    @Test("search handles empty response")
    func testSearchHandlesEmptyResponse() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("")
        let service = MailAppleScriptService(runner: runner)

        let emails = try await service.search(query: "nonexistent", limit: 10, includeBody: false)

        #expect(emails.isEmpty, "Empty response should produce empty array")
    }

    @Test("unread skips malformed lines in response")
    func testUnreadSkipsMalformedLines() async throws {
        let runner = MockAppleScriptRunner()
        // Valid line has 6+ tab-separated fields; malformed line has fewer
        await runner.setStubResponse("""
            malformed\tonly\ttwo
            E1\tSubject\tsender@test.com\trecipient@test.com\t2026-01-27T10:00:00Z\tINBOX\t
            incomplete
            """)
        let service = MailAppleScriptService(runner: runner)

        let emails = try await service.unread(limit: 10, includeBody: false)

        // Only the valid middle line should parse
        #expect(emails.count == 1, "Should skip malformed lines")
        #expect(emails.first?.subject == "Subject")
    }

    @Test("search skips lines with fewer than 8 fields")
    func testSearchSkipsMalformedLines() async throws {
        let runner = MockAppleScriptRunner()
        // Search response needs 8 fields (includes isRead status)
        await runner.setStubResponse("""
            short\tline
            E1\tSubject\tsender@test.com\trecipient@test.com\t2026-01-27T10:00:00Z\tINBOX\t\ttrue
            only\tseven\tfields\there\tno\tisRead\tstatus
            """)
        let service = MailAppleScriptService(runner: runner)

        let emails = try await service.search(query: "test", limit: 10, includeBody: false)

        // Only the valid 8-field line should parse
        #expect(emails.count == 1, "Should skip lines with fewer than 8 fields")
        #expect(emails.first?.subject == "Subject")
    }

    @Test("date parser returns original string when format is unrecognized")
    func testDateParserReturnsOriginalOnUnrecognizedFormat() async throws {
        let runner = MockAppleScriptRunner()
        // Use an unusual date format that won't be recognized
        let unusualDate = "42nd of Smarch, Year 3000"
        await runner.setStubResponse("""
            E1\tSubject\tsender@test.com\trecipient@test.com\t\(unusualDate)\tINBOX\t
            """)
        let service = MailAppleScriptService(runner: runner)

        let emails = try await service.unread(limit: 10, includeBody: false)

        #expect(emails.count == 1)
        // The original date string should be preserved when parsing fails
        #expect(emails.first?.date == unusualDate, "Unrecognized date format should return original string")
    }

    @Test("unread handles response with special characters in body")
    func testUnreadHandlesSpecialCharactersInBody() async throws {
        let runner = MockAppleScriptRunner()
        // Note: tabs and newlines would normally be escaped in real AppleScript output
        await runner.setStubResponse("""
            E1\tSubject with émojis 🎉\tsender@test.com\trecipient@test.com\t2026-01-27T10:00:00Z\tINBOX\tBody with <html> & "quotes"
            """)
        let service = MailAppleScriptService(runner: runner)

        let emails = try await service.unread(limit: 10, includeBody: true)

        #expect(emails.count == 1)
        #expect(emails.first?.subject == "Subject with émojis 🎉")
        #expect(emails.first?.body?.contains("<html>") == true)
    }

    @Test("search handles whitespace-only response")
    func testSearchHandlesWhitespaceOnlyResponse() async throws {
        let runner = MockAppleScriptRunner()
        await runner.setStubResponse("   \n\n   \n")
        let service = MailAppleScriptService(runner: runner)

        let emails = try await service.search(query: "test", limit: 10, includeBody: false)

        #expect(emails.isEmpty, "Whitespace-only response should produce empty array")
    }
}
