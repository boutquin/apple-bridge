import Testing
import Foundation
import MCP
@testable import MCPServer
@testable import AppleBridgeCore
@testable import TestUtilities

/// Tests for Contacts MCP tool handlers.
@Suite("Contacts Handler Tests")
struct ContactsHandlerTests {

    // MARK: - contacts_search Tests

    @Test("contacts_search returns matching contacts")
    func testContactsSearchReturnsMatches() async throws {
        let services = makeTestServices()
        await services.mockContacts.setStubContacts([
            makeTestContact(id: "C1", displayName: "John Doe"),
            makeTestContact(id: "C2", displayName: "Jane Smith")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_search",
            arguments: ["query": .string("John"), "limit": .int(10)]
        )

        #expect(result.isError == false)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("John Doe"))
            #expect(!text.contains("Jane Smith"))
        }
    }

    @Test("contacts_search requires query parameter")
    func testContactsSearchRequiresQuery() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_search",
            arguments: ["limit": .int(10)]
        )

        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("query"))
        }
    }

    @Test("contacts_search uses default limit when not provided")
    func testContactsSearchUsesDefaultLimit() async throws {
        let services = makeTestServices()
        await services.mockContacts.setStubContacts([
            makeTestContact(id: "C1", displayName: "Test 1"),
            makeTestContact(id: "C2", displayName: "Test 2")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_search",
            arguments: ["query": .string("Test")]
        )

        #expect(result.isError == false)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Test 1"))
        }
    }

    // MARK: - contacts_get Tests

    @Test("contacts_get returns contact by ID")
    func testContactsGetReturnsContactById() async throws {
        let services = makeTestServices()
        await services.mockContacts.setStubContacts([
            makeTestContact(id: "C1", displayName: "John Doe", email: "john@example.com")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_get",
            arguments: ["id": .string("C1")]
        )

        #expect(result.isError == false)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("John Doe"))
            #expect(text.contains("john@example.com"))
        }
    }

    @Test("contacts_get requires id parameter")
    func testContactsGetRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_get",
            arguments: [:]
        )

        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("id"))
        }
    }

    @Test("contacts_get returns error for invalid ID")
    func testContactsGetReturnsErrorForInvalidId() async throws {
        let services = makeTestServices()
        await services.mockContacts.setStubContacts([])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_get",
            arguments: ["id": .string("nonexistent")]
        )

        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("not found") || text.contains("Contact"))
        }
    }

    // MARK: - contacts_me Tests

    @Test("contacts_me returns user's contact card")
    func testContactsMeReturnsUsersCard() async throws {
        let services = makeTestServices()
        await services.mockContacts.setStubMeContact(
            makeTestContact(id: "ME", displayName: "Pierre Boutquin")
        )
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_me",
            arguments: nil
        )

        #expect(result.isError == false)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Pierre Boutquin"))
        }
    }

    @Test("contacts_me returns null when not configured")
    func testContactsMeReturnsNullWhenNotConfigured() async throws {
        let services = makeTestServices()
        await services.mockContacts.setStubMeContact(nil)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_me",
            arguments: nil
        )

        #expect(result.isError == false)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("null"))
        }
    }

    // MARK: - contacts_open Tests

    @Test("contacts_open succeeds for valid ID")
    func testContactsOpenSucceedsForValidId() async throws {
        let services = makeTestServices()
        await services.mockContacts.setStubContacts([
            makeTestContact(id: "C1", displayName: "John Doe")
        ])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_open",
            arguments: ["id": .string("C1")]
        )

        #expect(result.isError == false)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("C1") || text.contains("opened"))
        }
    }

    @Test("contacts_open requires id parameter")
    func testContactsOpenRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_open",
            arguments: [:]
        )

        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("id"))
        }
    }

    @Test("contacts_open returns error for invalid ID")
    func testContactsOpenReturnsErrorForInvalidId() async throws {
        let services = makeTestServices()
        await services.mockContacts.setStubContacts([])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_open",
            arguments: ["id": .string("nonexistent")]
        )

        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("not found") || text.contains("Contact"))
        }
    }

    // MARK: - Permission Error Tests

    @Test("contacts_search returns permission error when denied")
    func testContactsSearchReturnsPermissionError() async throws {
        let services = makeTestServices()
        await services.mockContacts.setError(PermissionError.contactsDenied)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "contacts_search",
            arguments: ["query": .string("test")]
        )

        #expect(result.isError == true)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Contacts") || text.contains("permission") || text.contains("denied"))
        }
    }

    // MARK: - contacts_create

    @Test("contacts_create creates a contact and returns its new id")
    func testContactsCreateReturnsNewContact() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "contacts_create", arguments: [
            "givenName": .string("Ada"),
            "familyName": .string("Lovelace"),
            "organization": .string("Analytical Engines"),
            "jobTitle": .string("Chief Mathematician"),
            "note": .string("Multi-line\nnote with \"quotes\"."),
            "emails": .array([.object(["label": .string("work"), "value": .string("ada@example.com")])]),
            "urls": .array([.string("https://example.com")])
        ])

        #expect(result.isError == false)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Ada"))
            #expect(text.contains("ada@example.com"))
            #expect(text.contains("Analytical Engines"))
            // JSONEncoder escapes forward slashes (`https:\/\/`), which is valid
            // JSON; assert on the unescaped host rather than the full URL.
            #expect(text.contains("example.com"))
            #expect(text.contains("\"urls\""))
        }
        #expect(await services.mockContacts.createdContacts.count == 1)
    }

    @Test("contacts_create requires at least one name field")
    func testContactsCreateRequiresAName() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "contacts_create", arguments: [
            "organization": .string("No Name Ltd")
        ])

        #expect(result.isError == true)
        #expect(await services.mockContacts.createdContacts.isEmpty, "a rejected create must not reach the service")
    }

    @Test("contacts_create rejects a singular and its plural together")
    func testContactsCreateRejectsSingularAndPlural() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "contacts_create", arguments: [
            "givenName": .string("Ada"),
            "email": .string("one@example.com"),
            "emails": .array([.string("two@example.com")])
        ])

        #expect(result.isError == true)
        #expect(await services.mockContacts.createdContacts.isEmpty)
    }

    // MARK: - contacts_update

    @Test("contacts_update changes only the supplied field")
    func testContactsUpdateLeavesAbsentFieldsAlone() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let created = await registry.callTool(name: "contacts_create", arguments: [
            "givenName": .string("Ada"),
            "organization": .string("Analytical Engines"),
            "note": .string("keep me")
        ])
        #expect(created.isError == false)
        let id = await services.mockContacts.createdContacts.isEmpty
            ? "" : "mock-contact-1"

        let result = await registry.callTool(name: "contacts_update", arguments: [
            "id": .string(id),
            "jobTitle": .string("Chief Mathematician")
        ])

        #expect(result.isError == false)
        if case .text(let text, _, _) = result.content.first {
            #expect(text.contains("Chief Mathematician"))
            #expect(text.contains("Analytical Engines"), "an absent field must survive the update")
            #expect(text.contains("keep me"))
        }
    }

    @Test("contacts_update requires id")
    func testContactsUpdateRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "contacts_update", arguments: [
            "jobTitle": .string("Nobody")
        ])

        #expect(result.isError == true)
    }

    @Test("contacts_update on an unknown id returns not-found")
    func testContactsUpdateUnknownId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "contacts_update", arguments: [
            "id": .string("does-not-exist"),
            "jobTitle": .string("Ghost")
        ])

        #expect(result.isError == true)
    }

    @Test("Both write tools are registered")
    func testWriteToolsAreRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)
        let names = await registry.definitions.map(\.name)

        #expect(names.contains("contacts_create"))
        #expect(names.contains("contacts_update"))
        #expect(names.filter { $0.hasPrefix("contacts_") }.count == 6)
    }
}
