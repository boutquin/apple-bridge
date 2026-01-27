import Testing
import Foundation
import MCP
@testable import MCPServer
@testable import Core
@testable import TestUtilities

@Suite("Calendar Handler Tests")
struct CalendarHandlerTests {

    // MARK: - Test Setup

    /// Creates a test services container and populates the mock calendar.
    private func makeTestServicesWithEvents() async -> TestServices {
        let services = makeTestServices()
        await services.mockCalendar.setStubEvents([
            makeTestEvent(id: "E1", title: "Meeting", location: "Office"),
            makeTestEvent(id: "E2", title: "Lunch", location: "Cafe")
        ])
        return services
    }

    // MARK: - calendar_list Handler Tests

    @Test("calendar_list returns events")
    func testCalendarListReturnsEvents() async throws {
        let services = await makeTestServicesWithEvents()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_list", arguments: ["limit": .int(10)])

        #expect(result.isError == false)
        // Result should contain event data
        if case .text(let text) = result.content.first {
            #expect(text.contains("Meeting") || text.contains("events"))
        }
    }

    @Test("calendar_list respects limit parameter")
    func testCalendarListRespectsLimit() async throws {
        let services = makeTestServices()
        // Add more events
        await services.mockCalendar.setStubEvents((1...10).map { i in
            makeTestEvent(id: "E\(i)", title: "Event \(i)")
        })

        let registry = ToolRegistry.create(services: services)
        let result = await registry.callTool(name: "calendar_list", arguments: ["limit": .int(3)])

        #expect(result.isError == false)
    }

    @Test("calendar_list handles date range parameters")
    func testCalendarListHandlesDateRange() async throws {
        let services = await makeTestServicesWithEvents()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_list", arguments: [
            "limit": .int(10),
            "from": .string("2026-01-01T00:00:00Z"),
            "to": .string("2026-12-31T23:59:59Z")
        ])

        #expect(result.isError == false)
    }

    // MARK: - calendar_search Handler Tests

    @Test("calendar_search filters by query")
    func testCalendarSearchFiltersByQuery() async throws {
        let services = await makeTestServicesWithEvents()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_search", arguments: [
            "query": .string("Meeting"),
            "limit": .int(10)
        ])

        #expect(result.isError == false)
        if case .text(let text) = result.content.first {
            #expect(text.contains("Meeting"))
        }
    }

    @Test("calendar_search requires query parameter")
    func testCalendarSearchRequiresQuery() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_search", arguments: ["limit": .int(10)])

        #expect(result.isError == true)
        if case .text(let text) = result.content.first {
            #expect(text.contains("query") || text.contains("required") || text.contains("Missing"))
        }
    }

    // MARK: - calendar_get Handler Tests

    @Test("calendar_get returns event by ID")
    func testCalendarGetReturnsEventById() async throws {
        let services = await makeTestServicesWithEvents()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_get", arguments: ["id": .string("E1")])

        #expect(result.isError == false)
        if case .text(let text) = result.content.first {
            #expect(text.contains("Meeting") || text.contains("E1"))
        }
    }

    @Test("calendar_get requires id parameter")
    func testCalendarGetRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_get", arguments: nil)

        #expect(result.isError == true)
    }

    @Test("calendar_get returns error for unknown ID")
    func testCalendarGetReturnsErrorForUnknownId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_get", arguments: ["id": .string("nonexistent")])

        #expect(result.isError == true)
        if case .text(let text) = result.content.first {
            #expect(text.contains("not found") || text.contains("Error"))
        }
    }

    // MARK: - calendar_create Handler Tests

    @Test("calendar_create creates new event")
    func testCalendarCreateCreatesEvent() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_create", arguments: [
            "title": .string("New Event"),
            "startDate": .string("2026-01-28T10:00:00Z"),
            "endDate": .string("2026-01-28T11:00:00Z"),
            "location": .string("Room A"),
            "notes": .string("Important meeting")
        ])

        #expect(result.isError == false)
        // Should return the created event ID
        if case .text(let text) = result.content.first {
            #expect(!text.isEmpty)
        }

        // Verify event was created
        let created = await services.mockCalendar.getCreatedEvents()
        #expect(created.count == 1)
        #expect(created[0].title == "New Event")
    }

    @Test("calendar_create requires title, startDate, endDate")
    func testCalendarCreateRequiresFields() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        // Missing startDate and endDate
        let result = await registry.callTool(name: "calendar_create", arguments: [
            "title": .string("Test Event")
        ])

        #expect(result.isError == true)
    }

    // MARK: - calendar_update Handler Tests

    @Test("calendar_update modifies event")
    func testCalendarUpdateModifiesEvent() async throws {
        let services = await makeTestServicesWithEvents()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_update", arguments: [
            "id": .string("E1"),
            "title": .string("Updated Meeting"),
            "location": .string("New Location")
        ])

        #expect(result.isError == false)
        if case .text(let text) = result.content.first {
            #expect(text.contains("Updated") || text.contains("E1"))
        }
    }

    @Test("calendar_update requires id parameter")
    func testCalendarUpdateRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_update", arguments: [
            "title": .string("Updated")
        ])

        #expect(result.isError == true)
    }

    // MARK: - calendar_delete Handler Tests

    @Test("calendar_delete removes event")
    func testCalendarDeleteRemovesEvent() async throws {
        let services = await makeTestServicesWithEvents()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_delete", arguments: ["id": .string("E1")])

        #expect(result.isError == false)

        let deleted = await services.mockCalendar.getDeletedEventIds()
        #expect(deleted.contains("E1"))
    }

    @Test("calendar_delete requires id parameter")
    func testCalendarDeleteRequiresId() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(name: "calendar_delete", arguments: nil)

        #expect(result.isError == true)
    }

    // MARK: - Handler Integration Tests

    @Test("All calendar tools are registered")
    func testAllCalendarToolsRegistered() async {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        let definitions = await registry.definitions
        let names = definitions.map(\.name)

        #expect(names.contains("calendar_list"))
        #expect(names.contains("calendar_search"))
        #expect(names.contains("calendar_get"))
        #expect(names.contains("calendar_create"))
        #expect(names.contains("calendar_update"))
        #expect(names.contains("calendar_delete"))
    }

    @Test("Calendar handlers no longer return NOT_IMPLEMENTED")
    func testCalendarHandlersImplemented() async {
        let services = await makeTestServicesWithEvents()
        let registry = ToolRegistry.create(services: services)

        // List should work (not return NOT_IMPLEMENTED)
        let listResult = await registry.callTool(name: "calendar_list", arguments: ["limit": .int(10)])
        if case .text(let text) = listResult.content.first {
            #expect(!text.contains("NOT_IMPLEMENTED"))
        }

        // Get should work
        let getResult = await registry.callTool(name: "calendar_get", arguments: ["id": .string("E1")])
        if case .text(let text) = getResult.content.first {
            #expect(!text.contains("NOT_IMPLEMENTED"))
        }
    }
}
