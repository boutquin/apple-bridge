import Testing
import Foundation
import MCP
@testable import MCPServer
@testable import Core
@testable import TestUtilities

/// Tests for Mail MCP tool handlers.
///
/// These tests verify that the MCP handlers correctly:
/// - Extract arguments
/// - Call the MailService
/// - Format responses
/// - Handle errors
@Suite("Mail Handler Tests")
struct MailHandlerTests {

    // MARK: - mail_search

    @Test("mail_search returns matching emails")
    func testSearchReturnsMatchingEmails() async {
        let services = makeTestServices()
        await services.mockMail.setStubEmails([
            makeTestEmail(id: "E1", subject: "Meeting tomorrow"),
            makeTestEmail(id: "E2", subject: "Lunch plans"),
            makeTestEmail(id: "E3", subject: "Meeting notes")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_search",
            arguments: ["query": .string("Meeting"), "limit": .int(10), "includeBody": .bool(false)]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Meeting"))
        }
    }

    @Test("mail_search requires query parameter")
    func testSearchRequiresQuery() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_search",
            arguments: ["limit": .int(10)]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("query"))
        }
    }

    @Test("mail_search uses default limit")
    func testSearchUsesDefaultLimit() async {
        let services = makeTestServices()
        await services.mockMail.setStubEmails([
            makeTestEmail(id: "E1", subject: "Test")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_search",
            arguments: ["query": .string("Test")]
        )

        #expect(result.isError == false)
    }

    @Test("mail_search includes body when requested")
    func testSearchIncludesBody() async {
        let services = makeTestServices()
        await services.mockMail.setStubEmails([
            makeTestEmail(id: "E1", subject: "Test", body: "Email body content")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_search",
            arguments: ["query": .string("Test"), "includeBody": .bool(true)]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("body") || content.contains("Email body content"))
        }
    }

    // MARK: - mail_unread

    @Test("mail_unread returns unread emails")
    func testUnreadReturnsUnreadEmails() async {
        let services = makeTestServices()
        await services.mockMail.setStubEmails([
            makeTestEmail(id: "E1", subject: "Unread 1", isUnread: true),
            makeTestEmail(id: "E2", subject: "Read", isUnread: false),
            makeTestEmail(id: "E3", subject: "Unread 2", isUnread: true)
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_unread",
            arguments: ["limit": .int(10), "includeBody": .bool(false)]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Unread"))
        }
    }

    @Test("mail_unread uses default limit")
    func testUnreadUsesDefaultLimit() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_unread",
            arguments: nil
        )

        #expect(result.isError == false)
    }

    @Test("mail_unread respects includeBody parameter")
    func testUnreadRespectsIncludeBody() async {
        let services = makeTestServices()
        await services.mockMail.setStubEmails([
            makeTestEmail(id: "E1", subject: "Test", body: "Body content", isUnread: true)
        ])
        let registry = ToolRegistry.create(services: services)

        // With includeBody: false
        let resultWithoutBody = await registry.callTool(
            name: "mail_unread",
            arguments: ["includeBody": .bool(false)]
        )
        #expect(resultWithoutBody.isError == false)
    }

    // MARK: - mail_send

    @Test("mail_send calls service with correct parameters")
    func testSendCallsServiceWithCorrectParameters() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_send",
            arguments: [
                "to": .array([.string("recipient@example.com")]),
                "subject": .string("Test Subject"),
                "body": .string("Test Body")
            ]
        )

        #expect(result.isError == false)

        // Verify the mock received the send call
        let sentEmails = await services.mockMail.getSentEmails()
        #expect(sentEmails.count == 1)
        #expect(sentEmails[0].to == ["recipient@example.com"])
        #expect(sentEmails[0].subject == "Test Subject")
        #expect(sentEmails[0].body == "Test Body")
    }

    @Test("mail_send handles multiple recipients")
    func testSendHandlesMultipleRecipients() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_send",
            arguments: [
                "to": .array([.string("one@example.com"), .string("two@example.com")]),
                "subject": .string("Test"),
                "body": .string("Body")
            ]
        )

        #expect(result.isError == false)

        let sentEmails = await services.mockMail.getSentEmails()
        #expect(sentEmails.count == 1)
        #expect(sentEmails[0].to.count == 2)
    }

    @Test("mail_send includes CC and BCC")
    func testSendIncludesCcAndBcc() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_send",
            arguments: [
                "to": .array([.string("to@example.com")]),
                "subject": .string("Test"),
                "body": .string("Body"),
                "cc": .array([.string("cc@example.com")]),
                "bcc": .array([.string("bcc@example.com")])
            ]
        )

        #expect(result.isError == false)

        let sentEmails = await services.mockMail.getSentEmails()
        #expect(sentEmails.count == 1)
        #expect(sentEmails[0].cc == ["cc@example.com"])
        #expect(sentEmails[0].bcc == ["bcc@example.com"])
    }

    @Test("mail_send requires to parameter")
    func testSendRequiresTo() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_send",
            arguments: [
                "subject": .string("Test"),
                "body": .string("Body")
            ]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("to"))
        }
    }

    @Test("mail_send requires subject parameter")
    func testSendRequiresSubject() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_send",
            arguments: [
                "to": .array([.string("to@example.com")]),
                "body": .string("Body")
            ]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("subject"))
        }
    }

    @Test("mail_send requires body parameter")
    func testSendRequiresBody() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_send",
            arguments: [
                "to": .array([.string("to@example.com")]),
                "subject": .string("Test")
            ]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("body"))
        }
    }

    @Test("mail_send returns success response")
    func testSendReturnsSuccessResponse() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_send",
            arguments: [
                "to": .array([.string("to@example.com")]),
                "subject": .string("Test"),
                "body": .string("Body")
            ]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("sent") || content.contains("true"))
        }
    }

    // MARK: - mail_compose

    @Test("mail_compose calls service with correct parameters")
    func testComposeCallsServiceWithCorrectParameters() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_compose",
            arguments: [
                "to": .array([.string("recipient@example.com")]),
                "subject": .string("Draft Subject"),
                "body": .string("Draft Body")
            ]
        )

        #expect(result.isError == false)

        // Verify the mock received the compose call
        let composeRequests = await services.mockMail.getComposeRequests()
        #expect(composeRequests.count == 1)
        #expect(composeRequests[0].to == ["recipient@example.com"])
        #expect(composeRequests[0].subject == "Draft Subject")
        #expect(composeRequests[0].body == "Draft Body")
    }

    @Test("mail_compose works with no parameters")
    func testComposeWorksWithNoParameters() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_compose",
            arguments: nil
        )

        #expect(result.isError == false)

        let composeRequests = await services.mockMail.getComposeRequests()
        #expect(composeRequests.count == 1)
    }

    @Test("mail_compose returns success response")
    func testComposeReturnsSuccessResponse() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_compose",
            arguments: [
                "subject": .string("Test")
            ]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("compose") || content.contains("opened") || content.contains("true"))
        }
    }

    // MARK: - Error Handling

    @Test("handlers propagate service errors")
    func testHandlersPropagateServiceErrors() async {
        let services = makeTestServices()
        await services.mockMail.setError(AppleScriptError.executionFailed(message: "Mail not available"))
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_search",
            arguments: ["query": .string("test")]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Error") || content.contains("Mail"))
        }
    }

    @Test("handlers handle AppleScript timeout errors")
    func testHandlersHandleTimeoutErrors() async {
        let services = makeTestServices()
        await services.mockMail.setError(AppleScriptError.timeout(seconds: 30))
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "mail_unread",
            arguments: nil
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Error") || content.contains("timeout"))
        }
    }
}
