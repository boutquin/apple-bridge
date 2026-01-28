import Foundation
import Core

/// Implementation of `CalendarService` using EventKit via an adapter.
///
/// This service translates between the high-level `CalendarService` protocol
/// (using ISO 8601 string dates) and the lower-level `CalendarAdapterProtocol`
/// (using Foundation `Date` objects).
///
/// ## Example
/// ```swift
/// let adapter = EventKitAdapter()
/// let service = EventKitCalendarService(adapter: adapter)
/// let events = try await service.listEvents(limit: 10, from: nil, to: nil, cursor: nil)
/// ```
public struct EventKitCalendarService: CalendarService, Sendable {

    /// The adapter used to interact with calendar backend.
    private let adapter: any CalendarAdapterProtocol

    /// Default range start: 1 year ago.
    private static let defaultFromOffset: TimeInterval = -365 * 24 * 60 * 60

    /// Default range end: 1 year from now.
    private static let defaultToOffset: TimeInterval = 365 * 24 * 60 * 60

    /// Creates a new calendar service with the given adapter.
    /// - Parameter adapter: The calendar adapter to use for calendar operations.
    public init(adapter: any CalendarAdapterProtocol) {
        self.adapter = adapter
    }

    // MARK: - CalendarService Protocol

    public func listEvents(limit: Int, from: String?, to: String?, cursor: String?) async throws -> Page<CalendarEvent> {
        let fromDate = parseDate(from) ?? Date().addingTimeInterval(Self.defaultFromOffset)
        let toDate = parseDate(to) ?? Date().addingTimeInterval(Self.defaultToOffset)

        let allEvents = try await adapter.fetchEvents(from: fromDate, to: toDate, calendarId: nil)

        // Apply cursor-based pagination
        let startIndex = decodeCursorOffset(cursor)
        let paginatedEvents = Array(allEvents.dropFirst(startIndex))
        let limitedEvents = Array(paginatedEvents.prefix(limit))
        let hasMore = paginatedEvents.count > limit

        let items = limitedEvents.map(convertToCalendarEvent)
        let nextCursor = hasMore ? encodeCursor(offset: startIndex + limit) : nil

        return Page(items: items, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func searchEvents(query: String, limit: Int, from: String?, to: String?, cursor: String?) async throws -> Page<CalendarEvent> {
        let fromDate = parseDate(from) ?? Date().addingTimeInterval(Self.defaultFromOffset)
        let toDate = parseDate(to) ?? Date().addingTimeInterval(Self.defaultToOffset)

        let allEvents = try await adapter.fetchEvents(from: fromDate, to: toDate, calendarId: nil)

        // Filter by query (case-insensitive search in title, location, notes)
        let filtered = allEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(query) ||
            (event.location?.localizedCaseInsensitiveContains(query) ?? false) ||
            (event.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }

        // Apply cursor-based pagination
        let startIndex = decodeCursorOffset(cursor)
        let paginatedEvents = Array(filtered.dropFirst(startIndex))
        let limitedEvents = Array(paginatedEvents.prefix(limit))
        let hasMore = paginatedEvents.count > limit

        let items = limitedEvents.map(convertToCalendarEvent)
        let nextCursor = hasMore ? encodeCursor(offset: startIndex + limit) : nil

        return Page(items: items, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func getEvent(id: String) async throws -> CalendarEvent {
        let event = try await adapter.fetchEvent(id: id)
        return convertToCalendarEvent(event)
    }

    public func createEvent(title: String, startDate: String, endDate: String, calendarId: String?, location: String?, notes: String?) async throws -> String {
        guard let start = parseDate(startDate) else {
            throw ValidationError.invalidFormat(field: "startDate", expected: "ISO 8601")
        }
        guard let end = parseDate(endDate) else {
            throw ValidationError.invalidFormat(field: "endDate", expected: "ISO 8601")
        }

        return try await adapter.createEvent(
            title: title,
            startDate: start,
            endDate: end,
            calendarId: calendarId,
            location: location,
            notes: notes
        )
    }

    public func updateEvent(id: String, patch: CalendarEventPatch) async throws -> CalendarEvent {
        let startDate: Date? = try patch.startDate.flatMap { str -> Date? in
            guard let date = parseDate(str) else {
                throw ValidationError.invalidFormat(field: "startDate", expected: "ISO 8601")
            }
            return date
        }
        let endDate: Date? = try patch.endDate.flatMap { str -> Date? in
            guard let date = parseDate(str) else {
                throw ValidationError.invalidFormat(field: "endDate", expected: "ISO 8601")
            }
            return date
        }

        let updated = try await adapter.updateEvent(
            id: id,
            title: patch.title,
            startDate: startDate,
            endDate: endDate,
            location: patch.location,
            notes: patch.notes
        )

        return convertToCalendarEvent(updated)
    }

    public func deleteEvent(id: String) async throws {
        try await adapter.deleteEvent(id: id)
    }

    public func openEvent(id: String) async throws {
        try await adapter.openEvent(id: id)
    }

    // MARK: - Private Helpers

    /// Converts a `CalendarEventData` to a `CalendarEvent`.
    private func convertToCalendarEvent(_ event: CalendarEventData) -> CalendarEvent {
        CalendarEvent(
            id: event.id,
            title: event.title,
            startDate: formatDate(event.startDate),
            endDate: formatDate(event.endDate),
            calendarId: event.calendarId,
            location: event.location,
            notes: event.notes
        )
    }

    /// Formats a Date as an ISO 8601 string.
    /// - Note: Creates a new formatter each call to be Sendable-safe (ISO8601DateFormatter is not Sendable).
    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Parses an ISO 8601 date string to a Date.
    /// - Parameter dateString: The date string to parse (optional).
    /// - Returns: The parsed Date, or nil if the string was nil or invalid.
    /// - Note: Creates new formatters each call to be Sendable-safe.
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }

        // Try with fractional seconds first
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }

        return nil
    }

    /// Encodes a cursor from an offset value.
    private func encodeCursor(offset: Int) -> String {
        return "offset:\(offset)"
    }

    /// Decodes an offset from a cursor string.
    /// - Parameter cursor: The cursor string to decode.
    /// - Returns: The offset, or 0 if the cursor is nil or invalid.
    private func decodeCursorOffset(_ cursor: String?) -> Int {
        guard let cursor, cursor.hasPrefix("offset:") else { return 0 }
        let offsetStr = cursor.dropFirst("offset:".count)
        return Int(offsetStr) ?? 0
    }
}
