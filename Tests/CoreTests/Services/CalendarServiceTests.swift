import Testing
import Foundation
@testable import Core
import TestUtilities

@Suite("CalendarService Protocol Tests")
struct CalendarServiceTests {

    // MARK: - Protocol Conformance Tests

    @Test func testMockCalendarServiceConforms() async throws {
        let mock = MockCalendarService()
        let events = try await mock.listEvents(limit: 10, from: nil, to: nil, cursor: nil)
        #expect(events.items.isEmpty)
    }

    @Test func testMockCalendarServiceIsSendable() {
        let mock = MockCalendarService()
        Task { @Sendable in _ = mock }
    }

    // MARK: - List Events Tests

    @Test func testListEventsWithStubData() async throws {
        let mock = MockCalendarService()
        await mock.setStubEvents([
            makeTestEvent(id: "E1", title: "Meeting 1"),
            makeTestEvent(id: "E2", title: "Meeting 2")
        ])

        let page = try await mock.listEvents(limit: 10, from: nil, to: nil, cursor: nil)
        #expect(page.items.count == 2)
        #expect(page.items[0].title == "Meeting 1")
    }

    @Test func testListEventsRespectsLimit() async throws {
        let mock = MockCalendarService()
        await mock.setStubEvents([
            makeTestEvent(id: "E1"),
            makeTestEvent(id: "E2"),
            makeTestEvent(id: "E3")
        ])

        let page = try await mock.listEvents(limit: 2, from: nil, to: nil, cursor: nil)
        #expect(page.items.count == 2)
        #expect(page.hasMore == true)
    }

    // MARK: - Search Events Tests

    @Test func testSearchEventsFilters() async throws {
        let mock = MockCalendarService()
        await mock.setStubEvents([
            makeTestEvent(id: "E1", title: "Team Meeting"),
            makeTestEvent(id: "E2", title: "Lunch Break"),
            makeTestEvent(id: "E3", title: "Meeting with Bob")
        ])

        let page = try await mock.searchEvents(query: "Meeting", limit: 10, from: nil, to: nil, cursor: nil)
        #expect(page.items.count == 2)
    }

    // MARK: - Get Event Tests

    @Test func testGetEventById() async throws {
        let mock = MockCalendarService()
        let testEvent = makeTestEvent(id: "E123", title: "Important Meeting")
        await mock.setStubEvents([testEvent])

        let event = try await mock.getEvent(id: "E123")
        #expect(event.id == "E123")
        #expect(event.title == "Important Meeting")
    }

    @Test func testGetEventNotFoundThrows() async throws {
        let mock = MockCalendarService()
        await mock.setStubEvents([])

        await #expect(throws: (any Error).self) {
            _ = try await mock.getEvent(id: "nonexistent")
        }
    }

    // MARK: - Create Event Tests

    @Test func testCreateEvent() async throws {
        let mock = MockCalendarService()

        let id = try await mock.createEvent(
            title: "New Event",
            startDate: "2026-01-28T10:00:00Z",
            endDate: "2026-01-28T11:00:00Z",
            calendarId: nil,
            location: nil,
            notes: nil
        )

        #expect(!id.isEmpty)
    }

    // MARK: - Update Event Tests

    @Test func testUpdateEvent() async throws {
        let mock = MockCalendarService()
        let testEvent = makeTestEvent(id: "E1", title: "Original Title")
        await mock.setStubEvents([testEvent])

        let patch = CalendarEventPatch(title: "Updated Title")
        let updated = try await mock.updateEvent(id: "E1", patch: patch)

        #expect(updated.title == "Updated Title")
    }

    // MARK: - Delete Event Tests

    @Test func testDeleteEvent() async throws {
        let mock = MockCalendarService()
        let testEvent = makeTestEvent(id: "E1")
        await mock.setStubEvents([testEvent])

        try await mock.deleteEvent(id: "E1")
        // No throw = success
    }

    // MARK: - Open Event Tests

    @Test func testOpenEvent() async throws {
        let mock = MockCalendarService()
        let testEvent = makeTestEvent(id: "E1")
        await mock.setStubEvents([testEvent])

        try await mock.openEvent(id: "E1")
        // No throw = success
    }
}
