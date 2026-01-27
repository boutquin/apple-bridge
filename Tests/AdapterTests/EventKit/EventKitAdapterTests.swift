import Testing
import Foundation
@testable import Adapters
@testable import Core

@Suite("EventKitAdapter Protocol Tests")
struct EventKitAdapterTests {

    // MARK: - Protocol Existence

    @Test("EventKitAdapterProtocol exists and is Sendable")
    func testProtocolExistsAndIsSendable() async {
        // Verify the protocol exists by creating a mock
        let mock = MockEventKitAdapter()

        // Verify it's Sendable by passing across actor boundary
        await Task { @Sendable in
            _ = mock
        }.value
    }

    // MARK: - Calendar Operations

    @Test("requestCalendarAccess returns authorization status")
    func testRequestCalendarAccess() async throws {
        let mock = MockEventKitAdapter()

        // When access is granted
        await mock.setCalendarAccessGranted(true)
        let granted = try await mock.requestCalendarAccess()
        #expect(granted == true)

        // When access is denied
        await mock.setCalendarAccessGranted(false)
        let denied = try await mock.requestCalendarAccess()
        #expect(denied == false)
    }

    @Test("fetchEvents returns events within date range")
    func testFetchEvents() async throws {
        let mock = MockEventKitAdapter()
        let baseDate = Date(timeIntervalSince1970: 1706400000) // Fixed date for testing
        let testEvents = [
            EKEventData(
                id: "E1",
                title: "Meeting",
                startDate: baseDate.addingTimeInterval(3600), // 1 hour after base
                endDate: baseDate.addingTimeInterval(7200),   // 2 hours after base
                calendarId: "cal-1",
                location: "Office",
                notes: "Important meeting"
            )
        ]
        await mock.setStubEvents(testEvents)

        let events = try await mock.fetchEvents(
            from: baseDate,
            to: baseDate.addingTimeInterval(86400), // Full day range
            calendarId: nil
        )

        #expect(events.count == 1)
        #expect(events[0].title == "Meeting")
    }

    @Test("fetchEvent retrieves single event by ID")
    func testFetchEvent() async throws {
        let mock = MockEventKitAdapter()
        let testEvent = EKEventData(
            id: "E1",
            title: "Test Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarId: "cal-1",
            location: nil,
            notes: nil
        )
        await mock.setStubEvents([testEvent])

        let event = try await mock.fetchEvent(id: "E1")
        #expect(event.id == "E1")
        #expect(event.title == "Test Event")
    }

    @Test("fetchEvent throws notFound for unknown ID")
    func testFetchEventNotFound() async throws {
        let mock = MockEventKitAdapter()

        await #expect(throws: ValidationError.self) {
            _ = try await mock.fetchEvent(id: "nonexistent")
        }
    }

    @Test("createEvent returns new event ID")
    func testCreateEvent() async throws {
        let mock = MockEventKitAdapter()

        let id = try await mock.createEvent(
            title: "New Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarId: nil,
            location: "Room A",
            notes: "Notes here"
        )

        #expect(!id.isEmpty)

        // Verify event was added
        let createdEvents = await mock.getCreatedEvents()
        #expect(createdEvents.count == 1)
        #expect(createdEvents[0].title == "New Event")
    }

    @Test("updateEvent modifies existing event")
    func testUpdateEvent() async throws {
        let mock = MockEventKitAdapter()
        let testEvent = EKEventData(
            id: "E1",
            title: "Original",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarId: "cal-1",
            location: nil,
            notes: nil
        )
        await mock.setStubEvents([testEvent])

        let updated = try await mock.updateEvent(
            id: "E1",
            title: "Updated Title",
            startDate: nil,
            endDate: nil,
            location: "New Location",
            notes: nil
        )

        #expect(updated.title == "Updated Title")
        #expect(updated.location == "New Location")
    }

    @Test("deleteEvent removes event")
    func testDeleteEvent() async throws {
        let mock = MockEventKitAdapter()
        let testEvent = EKEventData(
            id: "E1",
            title: "To Delete",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarId: "cal-1",
            location: nil,
            notes: nil
        )
        await mock.setStubEvents([testEvent])

        try await mock.deleteEvent(id: "E1")

        let deletedIds = await mock.getDeletedEventIds()
        #expect(deletedIds.contains("E1"))
    }

    @Test("openEvent opens in Calendar app")
    func testOpenEvent() async throws {
        let mock = MockEventKitAdapter()
        let testEvent = EKEventData(
            id: "E1",
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarId: "cal-1",
            location: nil,
            notes: nil
        )
        await mock.setStubEvents([testEvent])

        try await mock.openEvent(id: "E1")

        let openedIds = await mock.getOpenedEventIds()
        #expect(openedIds.contains("E1"))
    }

    // MARK: - Calendar List Operations

    @Test("fetchCalendars returns available calendars")
    func testFetchCalendars() async throws {
        let mock = MockEventKitAdapter()
        let calendars = [
            EKCalendarData(id: "cal-1", title: "Work", isWritable: true),
            EKCalendarData(id: "cal-2", title: "Personal", isWritable: true)
        ]
        await mock.setStubCalendars(calendars)

        let result = try await mock.fetchCalendars()

        #expect(result.count == 2)
        #expect(result[0].title == "Work")
    }

    @Test("defaultCalendarId returns default calendar")
    func testDefaultCalendarId() async throws {
        let mock = MockEventKitAdapter()
        await mock.setDefaultCalendarId("default-cal")

        let id = try await mock.defaultCalendarId()

        #expect(id == "default-cal")
    }

    // MARK: - Error Handling

    @Test("operations throw PermissionError when access denied")
    func testPermissionErrorOnAccessDenied() async throws {
        let mock = MockEventKitAdapter()
        await mock.setError(PermissionError.calendarDenied)

        await #expect(throws: PermissionError.self) {
            _ = try await mock.fetchEvents(from: Date(), to: Date(), calendarId: nil)
        }
    }
}
