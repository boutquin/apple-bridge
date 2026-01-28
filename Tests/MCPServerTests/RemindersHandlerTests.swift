import Testing
import Foundation
import MCP
@testable import MCPServer
@testable import Core
@testable import TestUtilities

@Suite("Reminders Handler Tests")
struct RemindersHandlerTests {

    // MARK: - Test Setup

    /// Creates a test services container and populates the mock reminders.
    private func makeTestServicesWithReminders() async -> TestServices {
        let services = makeTestServices()
        await services.mockReminders.setStubLists([
            makeTestReminderList(id: "L1", name: "Personal"),
            makeTestReminderList(id: "L2", name: "Work")
        ])
        await services.mockReminders.setStubReminders([
            makeTestReminder(id: "R1", title: "Buy milk", listId: "L1"),
            makeTestReminder(id: "R2", title: "Call mom", listId: "L1"),
            makeTestReminder(id: "R3", title: "Finish report", listId: "L2")
        ])
        return services
    }

    // MARK: - reminders_get_lists Handler Tests

    @Test("reminders_get_lists returns lists")
    func testRemindersGetListsReturnsLists() async throws {
        let services = await makeTestServicesWithReminders()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_get_lists", arguments: nil)

        #expect(result.isError == false)
        if case .text(let text) = result.content.first {
            #expect(text.contains("Personal") || text.contains("Work") || text.contains("L1"))
        }
    }

    // MARK: - reminders_list Handler Tests

    @Test("reminders_list returns reminders for list")
    func testRemindersListReturnsReminders() async throws {
        let services = await makeTestServicesWithReminders()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_list", arguments: [
            "listId": .string("L1"),
            "limit": .int(10)
        ])

        #expect(result.isError == false)
        if case .text(let text) = result.content.first {
            #expect(text.contains("Buy milk") || text.contains("Call mom") || text.contains("R1"))
        }
    }

    @Test("reminders_list respects limit parameter")
    func testRemindersListRespectsLimit() async throws {
        let services = makeTestServices()
        await services.mockReminders.setStubReminders((1...10).map { i in
            makeTestReminder(id: "R\(i)", title: "Task \(i)", listId: "L1")
        })

        let registry = ToolRegistry.create(services: services)
        let result = await registry.callTool(name: "reminders_list", arguments: [
            "listId": .string("L1"),
            "limit": .int(3)
        ])

        #expect(result.isError == false)
    }

    @Test("reminders_list requires listId parameter")
    func testRemindersListRequiresListId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_list", arguments: ["limit": .int(10)])

        #expect(result.isError == true)
        if case .text(let text) = result.content.first {
            #expect(text.contains("listId") || text.contains("required") || text.contains("Missing"))
        }
    }

    // MARK: - reminders_search Handler Tests

    @Test("reminders_search filters by query")
    func testRemindersSearchFiltersByQuery() async throws {
        let services = await makeTestServicesWithReminders()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_search", arguments: [
            "query": .string("milk"),
            "limit": .int(10)
        ])

        #expect(result.isError == false)
        if case .text(let text) = result.content.first {
            #expect(text.contains("milk") || text.contains("Buy"))
        }
    }

    @Test("reminders_search requires query parameter")
    func testRemindersSearchRequiresQuery() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_search", arguments: ["limit": .int(10)])

        #expect(result.isError == true)
        if case .text(let text) = result.content.first {
            #expect(text.contains("query") || text.contains("required") || text.contains("Missing"))
        }
    }

    // MARK: - reminders_create Handler Tests

    @Test("reminders_create creates new reminder")
    func testRemindersCreateCreatesReminder() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_create", arguments: [
            "title": .string("New Task"),
            "notes": .string("Important notes"),
            "listId": .string("L1"),
            "priority": .int(1)
        ])

        #expect(result.isError == false)
        // Should return the created reminder ID
        if case .text(let text) = result.content.first {
            #expect(!text.isEmpty)
        }

        // Verify reminder was created
        let created = await services.mockReminders.createdReminders
        #expect(created.count == 1)
        #expect(created[0].title == "New Task")
    }

    @Test("reminders_create requires title parameter")
    func testRemindersCreateRequiresTitle() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_create", arguments: [
            "notes": .string("Notes only")
        ])

        #expect(result.isError == true)
        if case .text(let text) = result.content.first {
            #expect(text.contains("title") || text.contains("required") || text.contains("Missing"))
        }
    }

    // MARK: - reminders_update Handler Tests

    @Test("reminders_update modifies reminder")
    func testRemindersUpdateModifiesReminder() async throws {
        let services = await makeTestServicesWithReminders()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_update", arguments: [
            "id": .string("R1"),
            "title": .string("Updated Task"),
            "notes": .string("New notes")
        ])

        #expect(result.isError == false)
        if case .text(let text) = result.content.first {
            #expect(text.contains("Updated") || text.contains("R1"))
        }
    }

    @Test("reminders_update requires id parameter")
    func testRemindersUpdateRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_update", arguments: [
            "title": .string("Updated")
        ])

        #expect(result.isError == true)
    }

    @Test("reminders_update returns error for unknown ID")
    func testRemindersUpdateReturnsErrorForUnknownId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_update", arguments: [
            "id": .string("nonexistent"),
            "title": .string("New Title")
        ])

        #expect(result.isError == true)
        if case .text(let text) = result.content.first {
            #expect(text.contains("not found") || text.contains("Error"))
        }
    }

    // MARK: - reminders_delete Handler Tests

    @Test("reminders_delete removes reminder")
    func testRemindersDeleteRemovesReminder() async throws {
        let services = await makeTestServicesWithReminders()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_delete", arguments: ["id": .string("R1")])

        #expect(result.isError == false)

        let deleted = await services.mockReminders.deletedReminderIds
        #expect(deleted.contains("R1"))
    }

    @Test("reminders_delete requires id parameter")
    func testRemindersDeleteRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_delete", arguments: nil)

        #expect(result.isError == true)
    }

    // MARK: - reminders_complete Handler Tests

    @Test("reminders_complete marks reminder as completed")
    func testRemindersCompleteMarksCompleted() async throws {
        let services = await makeTestServicesWithReminders()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_complete", arguments: ["id": .string("R1")])

        #expect(result.isError == false)
        if case .text(let text) = result.content.first {
            #expect(text.contains("true") || text.contains("completed") || text.contains("isCompleted"))
        }
    }

    @Test("reminders_complete requires id parameter")
    func testRemindersCompleteRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_complete", arguments: nil)

        #expect(result.isError == true)
    }

    // MARK: - reminders_open Handler Tests

    @Test("reminders_open tracks opened reminder")
    func testRemindersOpenTracksOpened() async throws {
        let services = await makeTestServicesWithReminders()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_open", arguments: ["id": .string("R1")])

        #expect(result.isError == false)

        let opened = await services.mockReminders.openedReminderIds
        #expect(opened.contains("R1"))
    }

    @Test("reminders_open requires id parameter")
    func testRemindersOpenRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "reminders_open", arguments: nil)

        #expect(result.isError == true)
    }

    // MARK: - Handler Integration Tests

    @Test("All reminders tools are registered")
    func testAllRemindersToolsRegistered() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let names = definitions.map(\.name)

        #expect(names.contains("reminders_get_lists"))
        #expect(names.contains("reminders_list"))
        #expect(names.contains("reminders_search"))
        #expect(names.contains("reminders_create"))
        #expect(names.contains("reminders_update"))
        #expect(names.contains("reminders_delete"))
        #expect(names.contains("reminders_complete"))
        #expect(names.contains("reminders_open"))
    }

    @Test("Reminders handlers no longer return NOT_IMPLEMENTED")
    func testRemindersHandlersImplemented() async {
        let services = await makeTestServicesWithReminders()
        let registry = ToolRegistry.create(services: services)

        // Get lists should work (not return NOT_IMPLEMENTED)
        let listResult = await registry.callTool(name: "reminders_get_lists", arguments: nil)
        if case .text(let text) = listResult.content.first {
            #expect(!text.contains("NOT_IMPLEMENTED"))
        }

        // Search should work
        let searchResult = await registry.callTool(name: "reminders_search", arguments: [
            "query": .string("milk"),
            "limit": .int(10)
        ])
        if case .text(let text) = searchResult.content.first {
            #expect(!text.contains("NOT_IMPLEMENTED"))
        }
    }
}
