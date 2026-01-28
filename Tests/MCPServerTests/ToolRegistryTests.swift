import Testing
import MCP
@testable import MCPServer
import TestUtilities

@Suite("ToolRegistry Tests")
struct ToolRegistryTests {

    // MARK: - Initialization Tests

    @Test("ToolRegistry initializes with all 37 tools")
    func testToolRegistryInitializesWithAllTools() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        #expect(definitions.count == 37, "Expected 37 tools, got \(definitions.count)")
    }

    @Test("ToolRegistry has no duplicate tool names")
    func testToolRegistryNoDuplicates() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let names = definitions.map(\.name)
        let uniqueNames = Set(names)

        #expect(names.count == uniqueNames.count, "Found duplicate tool names")
    }

    @Test("ToolRegistry stubs return NOT_IMPLEMENTED")
    func testToolRegistryStubsReturnNotImplemented() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        // Use a tool that's still a stub (notes_search) - calendar, reminders, and contacts tools are now implemented
        let result = await registry.callTool(name: "notes_search", arguments: nil)

        #expect(result.isError == true)

        // Check that at least one content item contains NOT_IMPLEMENTED
        let hasNotImplemented = result.content.contains { content in
            if case .text(let text) = content {
                return text.contains("NOT_IMPLEMENTED")
            }
            return false
        }
        #expect(hasNotImplemented, "Expected NOT_IMPLEMENTED in error response")
    }

    @Test("All tools follow domain_operation naming convention")
    func testToolRegistryToolNaming() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions

        for tool in definitions {
            #expect(tool.name.contains("_"), "Tool '\(tool.name)' must use domain_operation format")

            // Verify the tool name starts with a known domain
            let knownDomains = ["calendar", "reminders", "contacts", "notes", "messages", "mail", "maps"]
            let startsWithKnownDomain = knownDomains.contains { tool.name.hasPrefix($0 + "_") }
            #expect(startsWithKnownDomain, "Tool '\(tool.name)' must start with a known domain prefix")
        }
    }

    // MARK: - Tool Definition Tests

    @Test("Calendar tools are registered correctly")
    func testCalendarToolsRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let calendarTools = definitions.filter { $0.name.hasPrefix("calendar_") }

        // 6 calendar tools: list, search, get, create, update, delete
        #expect(calendarTools.count == 6, "Expected 6 calendar tools, got \(calendarTools.count)")

        let expectedNames = ["calendar_list", "calendar_search", "calendar_get", "calendar_create", "calendar_update", "calendar_delete"]
        for name in expectedNames {
            #expect(calendarTools.contains { $0.name == name }, "Missing calendar tool: \(name)")
        }
    }

    @Test("Reminders tools are registered correctly")
    func testRemindersToolsRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let remindersTools = definitions.filter { $0.name.hasPrefix("reminders_") }

        // 8 reminders tools: get_lists, list, search, create, update, delete, complete, open
        #expect(remindersTools.count == 8, "Expected 8 reminders tools, got \(remindersTools.count)")

        let expectedNames = ["reminders_get_lists", "reminders_list", "reminders_search", "reminders_create", "reminders_update", "reminders_delete", "reminders_complete", "reminders_open"]
        for name in expectedNames {
            #expect(remindersTools.contains { $0.name == name }, "Missing reminders tool: \(name)")
        }
    }

    @Test("Contacts tools are registered correctly")
    func testContactsToolsRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let contactsTools = definitions.filter { $0.name.hasPrefix("contacts_") }

        // 4 contacts tools: search, get, me, open
        #expect(contactsTools.count == 4, "Expected 4 contacts tools, got \(contactsTools.count)")

        let expectedNames = ["contacts_search", "contacts_get", "contacts_me", "contacts_open"]
        for name in expectedNames {
            #expect(contactsTools.contains { $0.name == name }, "Missing contacts tool: \(name)")
        }
    }

    @Test("Notes tools are registered correctly")
    func testNotesToolsRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let notesTools = definitions.filter { $0.name.hasPrefix("notes_") }

        // 4 notes tools: search, get, create, open
        #expect(notesTools.count == 4, "Expected 4 notes tools, got \(notesTools.count)")

        let expectedNames = ["notes_search", "notes_get", "notes_create", "notes_open"]
        for name in expectedNames {
            #expect(notesTools.contains { $0.name == name }, "Missing notes tool: \(name)")
        }
    }

    @Test("Messages tools are registered correctly")
    func testMessagesToolsRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let messagesTools = definitions.filter { $0.name.hasPrefix("messages_") }

        // 5 messages tools: list_chats, read, unread, send, schedule
        #expect(messagesTools.count == 5, "Expected 5 messages tools, got \(messagesTools.count)")

        let expectedNames = ["messages_list_chats", "messages_read", "messages_unread", "messages_send", "messages_schedule"]
        for name in expectedNames {
            #expect(messagesTools.contains { $0.name == name }, "Missing messages tool: \(name)")
        }
    }

    @Test("Mail tools are registered correctly")
    func testMailToolsRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let mailTools = definitions.filter { $0.name.hasPrefix("mail_") }

        // 4 mail tools: search, unread, send, compose
        #expect(mailTools.count == 4, "Expected 4 mail tools, got \(mailTools.count)")

        let expectedNames = ["mail_search", "mail_unread", "mail_send", "mail_compose"]
        for name in expectedNames {
            #expect(mailTools.contains { $0.name == name }, "Missing mail tool: \(name)")
        }
    }

    @Test("Maps tools are registered correctly")
    func testMapsToolsRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let mapsTools = definitions.filter { $0.name.hasPrefix("maps_") }

        // 6 maps tools: search, directions, open, list_guides, open_guide, nearby
        #expect(mapsTools.count == 6, "Expected 6 maps tools, got \(mapsTools.count)")

        let expectedNames = ["maps_search", "maps_directions", "maps_open", "maps_list_guides", "maps_open_guide", "maps_nearby"]
        for name in expectedNames {
            #expect(mapsTools.contains { $0.name == name }, "Missing maps tool: \(name)")
        }
    }

    // MARK: - Tool Call Tests

    @Test("Calling unknown tool returns error")
    func testUnknownToolReturnsError() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "unknown_tool", arguments: nil)

        #expect(result.isError == true)

        let hasUnknownToolError = result.content.contains { content in
            if case .text(let text) = content {
                return text.contains("UNKNOWN_TOOL") || text.contains("unknown")
            }
            return false
        }
        #expect(hasUnknownToolError, "Expected UNKNOWN_TOOL error message")
    }
}
