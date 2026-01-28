import Testing
import Foundation
@testable import Adapters
@testable import Core

@Suite("EventKitCalendarService Tests")
struct EventKitCalendarServiceTests {

    // MARK: - Test Setup Helpers

    /// Creates an ISO 8601 date string formatter.
    private var iso8601Formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    /// Fixed base date for deterministic testing.
    private var baseDate: Date {
        Date(timeIntervalSince1970: 1706400000) // 2024-01-28T00:00:00Z
    }

    /// Date range strings that encompass the baseDate for testing.
    private var testFromStr: String {
        iso8601Formatter.string(from: baseDate.addingTimeInterval(-86400)) // 1 day before
    }

    private var testToStr: String {
        iso8601Formatter.string(from: baseDate.addingTimeInterval(365 * 24 * 3600)) // 1 year after
    }

    // MARK: - listEvents Tests

    @Test("listEvents returns paginated events")
    func testListEventsReturnsPaginatedEvents() async throws {
        let mock = MockEventKitAdapter()
        let events = [
            CalendarEventData(id: "E1", title: "Event 1", startDate: baseDate.addingTimeInterval(3600), endDate: baseDate.addingTimeInterval(7200), calendarId: "cal-1", location: nil, notes: nil),
            CalendarEventData(id: "E2", title: "Event 2", startDate: baseDate.addingTimeInterval(10800), endDate: baseDate.addingTimeInterval(14400), calendarId: "cal-1", location: nil, notes: nil)
        ]
        await mock.setStubEvents(events)

        let service = EventKitCalendarService(adapter: mock)
        let page = try await service.listEvents(limit: 10, from: testFromStr, to: testToStr, cursor: nil)

        #expect(page.items.count == 2)
        #expect(page.items[0].title == "Event 1")
        #expect(page.items[1].title == "Event 2")
    }

    @Test("listEvents respects limit parameter")
    func testListEventsRespectsLimit() async throws {
        let mock = MockEventKitAdapter()
        let events = (1...10).map { i in
            CalendarEventData(
                id: "E\(i)",
                title: "Event \(i)",
                startDate: baseDate.addingTimeInterval(Double(i) * 3600),
                endDate: baseDate.addingTimeInterval(Double(i) * 3600 + 3600),
                calendarId: "cal-1",
                location: nil,
                notes: nil
            )
        }
        await mock.setStubEvents(events)

        let service = EventKitCalendarService(adapter: mock)
        let page = try await service.listEvents(limit: 5, from: testFromStr, to: testToStr, cursor: nil)

        #expect(page.items.count == 5)
        #expect(page.hasMore == true)
        #expect(page.nextCursor != nil)
    }

    @Test("listEvents filters by date range")
    func testListEventsFiltersByDateRange() async throws {
        let mock = MockEventKitAdapter()
        let events = [
            CalendarEventData(id: "E1", title: "Too Early", startDate: baseDate.addingTimeInterval(-7200), endDate: baseDate.addingTimeInterval(-3600), calendarId: "cal-1", location: nil, notes: nil),
            CalendarEventData(id: "E2", title: "In Range", startDate: baseDate.addingTimeInterval(3600), endDate: baseDate.addingTimeInterval(7200), calendarId: "cal-1", location: nil, notes: nil),
            CalendarEventData(id: "E3", title: "Too Late", startDate: baseDate.addingTimeInterval(100000), endDate: baseDate.addingTimeInterval(103600), calendarId: "cal-1", location: nil, notes: nil)
        ]
        await mock.setStubEvents(events)

        let service = EventKitCalendarService(adapter: mock)
        let formatter = iso8601Formatter
        let fromStr = formatter.string(from: baseDate)
        let toStr = formatter.string(from: baseDate.addingTimeInterval(86400))

        let page = try await service.listEvents(limit: 10, from: fromStr, to: toStr, cursor: nil)

        #expect(page.items.count == 1)
        #expect(page.items[0].title == "In Range")
    }

    @Test("listEvents converts CalendarEventData to CalendarEvent")
    func testListEventsConvertsToCalendarEvent() async throws {
        let mock = MockEventKitAdapter()
        let event = CalendarEventData(
            id: "E1",
            title: "Test Event",
            startDate: baseDate,
            endDate: baseDate.addingTimeInterval(3600),
            calendarId: "cal-1",
            location: "Office",
            notes: "Important"
        )
        await mock.setStubEvents([event])

        let service = EventKitCalendarService(adapter: mock)
        let page = try await service.listEvents(limit: 10, from: testFromStr, to: testToStr, cursor: nil)

        let item = page.items[0]
        #expect(item.id == "E1")
        #expect(item.title == "Test Event")
        #expect(item.calendarId == "cal-1")
        #expect(item.location == "Office")
        #expect(item.notes == "Important")
        // Verify dates are ISO 8601 strings
        #expect(item.startDate.contains("T"))
        #expect(item.endDate.contains("T"))
    }

    // MARK: - searchEvents Tests

    @Test("searchEvents filters by query in title")
    func testSearchEventsFiltersByTitle() async throws {
        let mock = MockEventKitAdapter()
        let events = [
            CalendarEventData(id: "E1", title: "Team Meeting", startDate: baseDate, endDate: baseDate.addingTimeInterval(3600), calendarId: "cal-1", location: nil, notes: nil),
            CalendarEventData(id: "E2", title: "Lunch", startDate: baseDate.addingTimeInterval(7200), endDate: baseDate.addingTimeInterval(10800), calendarId: "cal-1", location: nil, notes: nil)
        ]
        await mock.setStubEvents(events)

        let service = EventKitCalendarService(adapter: mock)
        let page = try await service.searchEvents(query: "Meeting", limit: 10, from: testFromStr, to: testToStr, cursor: nil)

        #expect(page.items.count == 1)
        #expect(page.items[0].title == "Team Meeting")
    }

    @Test("searchEvents filters by query in location")
    func testSearchEventsFiltersByLocation() async throws {
        let mock = MockEventKitAdapter()
        let events = [
            CalendarEventData(id: "E1", title: "Meeting", startDate: baseDate, endDate: baseDate.addingTimeInterval(3600), calendarId: "cal-1", location: "Conference Room A", notes: nil),
            CalendarEventData(id: "E2", title: "Lunch", startDate: baseDate.addingTimeInterval(7200), endDate: baseDate.addingTimeInterval(10800), calendarId: "cal-1", location: "Cafeteria", notes: nil)
        ]
        await mock.setStubEvents(events)

        let service = EventKitCalendarService(adapter: mock)
        let page = try await service.searchEvents(query: "Conference", limit: 10, from: testFromStr, to: testToStr, cursor: nil)

        #expect(page.items.count == 1)
        #expect(page.items[0].location == "Conference Room A")
    }

    @Test("searchEvents filters by query in notes")
    func testSearchEventsFiltersByNotes() async throws {
        let mock = MockEventKitAdapter()
        let events = [
            CalendarEventData(id: "E1", title: "Meeting", startDate: baseDate, endDate: baseDate.addingTimeInterval(3600), calendarId: "cal-1", location: nil, notes: "Discuss Q1 budget"),
            CalendarEventData(id: "E2", title: "Standup", startDate: baseDate.addingTimeInterval(7200), endDate: baseDate.addingTimeInterval(10800), calendarId: "cal-1", location: nil, notes: "Daily sync")
        ]
        await mock.setStubEvents(events)

        let service = EventKitCalendarService(adapter: mock)
        let page = try await service.searchEvents(query: "budget", limit: 10, from: testFromStr, to: testToStr, cursor: nil)

        #expect(page.items.count == 1)
        #expect(page.items[0].notes == "Discuss Q1 budget")
    }

    @Test("searchEvents is case-insensitive")
    func testSearchEventsIsCaseInsensitive() async throws {
        let mock = MockEventKitAdapter()
        let events = [
            CalendarEventData(id: "E1", title: "IMPORTANT Meeting", startDate: baseDate, endDate: baseDate.addingTimeInterval(3600), calendarId: "cal-1", location: nil, notes: nil)
        ]
        await mock.setStubEvents(events)

        let service = EventKitCalendarService(adapter: mock)
        let page = try await service.searchEvents(query: "important", limit: 10, from: testFromStr, to: testToStr, cursor: nil)

        #expect(page.items.count == 1)
    }

    // MARK: - getEvent Tests

    @Test("getEvent returns event by ID")
    func testGetEventReturnsEventById() async throws {
        let mock = MockEventKitAdapter()
        let event = CalendarEventData(id: "E1", title: "Test Event", startDate: baseDate, endDate: baseDate.addingTimeInterval(3600), calendarId: "cal-1", location: "Office", notes: "Notes")
        await mock.setStubEvents([event])

        let service = EventKitCalendarService(adapter: mock)
        let result = try await service.getEvent(id: "E1")

        #expect(result.id == "E1")
        #expect(result.title == "Test Event")
        #expect(result.location == "Office")
        #expect(result.notes == "Notes")
    }

    @Test("getEvent throws notFound for unknown ID")
    func testGetEventThrowsNotFound() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitCalendarService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            _ = try await service.getEvent(id: "nonexistent")
        }
    }

    // MARK: - createEvent Tests

    @Test("createEvent returns new event ID")
    func testCreateEventReturnsId() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitCalendarService(adapter: mock)
        let formatter = iso8601Formatter
        let startStr = formatter.string(from: baseDate)
        let endStr = formatter.string(from: baseDate.addingTimeInterval(3600))

        let id = try await service.createEvent(
            title: "New Event",
            startDate: startStr,
            endDate: endStr,
            calendarId: nil,
            location: "Room A",
            notes: "Test notes"
        )

        #expect(!id.isEmpty)
    }

    @Test("createEvent passes correct parameters to adapter")
    func testCreateEventPassesParameters() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitCalendarService(adapter: mock)
        let formatter = iso8601Formatter
        let startStr = formatter.string(from: baseDate)
        let endStr = formatter.string(from: baseDate.addingTimeInterval(3600))

        _ = try await service.createEvent(
            title: "Test Event",
            startDate: startStr,
            endDate: endStr,
            calendarId: "custom-cal",
            location: "Office",
            notes: "Important"
        )

        let created = await mock.getCreatedEvents()
        #expect(created.count == 1)
        #expect(created[0].title == "Test Event")
        #expect(created[0].calendarId == "custom-cal")
        #expect(created[0].location == "Office")
        #expect(created[0].notes == "Important")
    }

    @Test("createEvent throws for invalid date format")
    func testCreateEventThrowsForInvalidDate() async throws {
        let mock = MockEventKitAdapter()
        let service = EventKitCalendarService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            _ = try await service.createEvent(
                title: "Test",
                startDate: "not-a-date",
                endDate: "also-not-a-date",
                calendarId: nil,
                location: nil,
                notes: nil
            )
        }
    }

    // MARK: - updateEvent Tests

    @Test("updateEvent returns updated event")
    func testUpdateEventReturnsUpdated() async throws {
        let mock = MockEventKitAdapter()
        let event = CalendarEventData(id: "E1", title: "Original", startDate: baseDate, endDate: baseDate.addingTimeInterval(3600), calendarId: "cal-1", location: nil, notes: nil)
        await mock.setStubEvents([event])

        let service = EventKitCalendarService(adapter: mock)
        let patch = CalendarEventPatch(title: "Updated", startDate: nil, endDate: nil, location: "New Location", notes: nil)
        let result = try await service.updateEvent(id: "E1", patch: patch)

        #expect(result.title == "Updated")
        #expect(result.location == "New Location")
    }

    @Test("updateEvent throws notFound for unknown ID")
    func testUpdateEventThrowsNotFound() async throws {
        let mock = MockEventKitAdapter()
        let service = EventKitCalendarService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            _ = try await service.updateEvent(id: "nonexistent", patch: CalendarEventPatch(title: "New"))
        }
    }

    // MARK: - deleteEvent Tests

    @Test("deleteEvent removes event")
    func testDeleteEventRemovesEvent() async throws {
        let mock = MockEventKitAdapter()
        let event = CalendarEventData(id: "E1", title: "To Delete", startDate: baseDate, endDate: baseDate.addingTimeInterval(3600), calendarId: "cal-1", location: nil, notes: nil)
        await mock.setStubEvents([event])

        let service = EventKitCalendarService(adapter: mock)
        try await service.deleteEvent(id: "E1")

        let deleted = await mock.getDeletedEventIds()
        #expect(deleted.contains("E1"))
    }

    @Test("deleteEvent throws notFound for unknown ID")
    func testDeleteEventThrowsNotFound() async throws {
        let mock = MockEventKitAdapter()
        let service = EventKitCalendarService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            try await service.deleteEvent(id: "nonexistent")
        }
    }

    // MARK: - openEvent Tests

    @Test("openEvent tracks opened event")
    func testOpenEventTracksOpened() async throws {
        let mock = MockEventKitAdapter()
        let event = CalendarEventData(id: "E1", title: "Test", startDate: baseDate, endDate: baseDate.addingTimeInterval(3600), calendarId: "cal-1", location: nil, notes: nil)
        await mock.setStubEvents([event])

        let service = EventKitCalendarService(adapter: mock)
        try await service.openEvent(id: "E1")

        let opened = await mock.getOpenedEventIds()
        #expect(opened.contains("E1"))
    }

    @Test("openEvent throws notFound for unknown ID")
    func testOpenEventThrowsNotFound() async throws {
        let mock = MockEventKitAdapter()
        let service = EventKitCalendarService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            try await service.openEvent(id: "nonexistent")
        }
    }

    // MARK: - Service Sendable Tests

    @Test("EventKitCalendarService is Sendable")
    func testServiceIsSendable() async {
        let mock = MockEventKitAdapter()
        let service = EventKitCalendarService(adapter: mock)

        await Task { @Sendable in
            _ = service
        }.value
    }
}
