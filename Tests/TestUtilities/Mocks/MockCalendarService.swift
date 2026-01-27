import Foundation
import Core

/// Mock implementation of `CalendarService` for testing.
///
/// Provides stubbed data and tracks method calls for verification in tests.
/// All methods are actor-isolated for thread safety.
public actor MockCalendarService: CalendarService {

    /// Stubbed events to return from list and search operations.
    public var stubEvents: [CalendarEvent] = []

    /// Tracks events that have been created.
    public var createdEvents: [CalendarEvent] = []

    /// Tracks IDs of events that have been deleted.
    public var deletedEventIds: [String] = []

    /// Tracks IDs of events that have been opened.
    public var openedEventIds: [String] = []

    /// Error to throw (if set) for testing error scenarios.
    public var errorToThrow: (any Error)?

    /// Creates a new mock calendar service.
    public init() {}

    /// Sets stubbed events for testing (actor-isolated method).
    /// - Parameter events: Events to return from list/search operations.
    public func setStubEvents(_ events: [CalendarEvent]) {
        self.stubEvents = events
    }

    /// Sets an error to throw on subsequent operations.
    /// - Parameter error: Error to throw, or nil to clear.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    /// Gets the list of deleted event IDs for verification.
    /// - Returns: Array of deleted event IDs.
    public func getDeletedEventIds() -> [String] {
        return deletedEventIds
    }

    /// Gets the list of opened event IDs for verification.
    /// - Returns: Array of opened event IDs.
    public func getOpenedEventIds() -> [String] {
        return openedEventIds
    }

    /// Gets the list of created events for verification.
    /// - Returns: Array of created events.
    public func getCreatedEvents() -> [CalendarEvent] {
        return createdEvents
    }

    public func listEvents(limit: Int, from: String?, to: String?, cursor: String?) async throws -> Page<CalendarEvent> {
        if let error = errorToThrow { throw error }

        // Apply limit
        let limitedEvents = Array(stubEvents.prefix(limit))
        let hasMore = stubEvents.count > limit

        // Generate cursor if more items exist
        let nextCursor = hasMore ? "mock-cursor-\(limit)" : nil

        return Page(items: limitedEvents, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func searchEvents(query: String, limit: Int, from: String?, to: String?, cursor: String?) async throws -> Page<CalendarEvent> {
        if let error = errorToThrow { throw error }

        // Filter events by query (case-insensitive search in title)
        let filtered = stubEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(query) ||
            (event.location?.localizedCaseInsensitiveContains(query) ?? false) ||
            (event.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }

        let limitedEvents = Array(filtered.prefix(limit))
        let hasMore = filtered.count > limit
        let nextCursor = hasMore ? "mock-cursor-\(limit)" : nil

        return Page(items: limitedEvents, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func getEvent(id: String) async throws -> CalendarEvent {
        if let error = errorToThrow { throw error }

        guard let event = stubEvents.first(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "CalendarEvent", id: id)
        }

        return event
    }

    public func createEvent(title: String, startDate: String, endDate: String, calendarId: String?, location: String?, notes: String?) async throws -> String {
        if let error = errorToThrow { throw error }

        let id = UUID().uuidString
        let event = CalendarEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            calendarId: calendarId ?? "default-calendar",
            location: location,
            notes: notes
        )

        createdEvents.append(event)
        stubEvents.append(event)

        return id
    }

    public func updateEvent(id: String, patch: CalendarEventPatch) async throws -> CalendarEvent {
        if let error = errorToThrow { throw error }

        guard let index = stubEvents.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "CalendarEvent", id: id)
        }

        let existing = stubEvents[index]

        // Apply patch (non-nil fields override existing values)
        let updated = CalendarEvent(
            id: existing.id,
            title: patch.title ?? existing.title,
            startDate: patch.startDate ?? existing.startDate,
            endDate: patch.endDate ?? existing.endDate,
            calendarId: existing.calendarId,
            location: patch.location ?? existing.location,
            notes: patch.notes ?? existing.notes
        )

        stubEvents[index] = updated
        return updated
    }

    public func deleteEvent(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard let index = stubEvents.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "CalendarEvent", id: id)
        }

        stubEvents.remove(at: index)
        deletedEventIds.append(id)
    }

    public func openEvent(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard stubEvents.contains(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "CalendarEvent", id: id)
        }

        openedEventIds.append(id)
    }
}
