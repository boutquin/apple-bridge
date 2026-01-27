import Foundation

/// Protocol for interacting with Apple Calendar.
///
/// Defines operations for listing, searching, creating, updating,
/// and deleting calendar events. All implementations must be
/// `Sendable` for safe use across actor boundaries.
///
/// ## Example
/// ```swift
/// let service: CalendarService = EventKitCalendarService()
/// let events = try await service.listEvents(limit: 10, from: nil, to: nil, cursor: nil)
/// ```
public protocol CalendarService: Sendable {

    /// Lists calendar events within an optional date range.
    /// - Parameters:
    ///   - limit: Maximum number of events to return.
    ///   - from: Start of date range in ISO 8601 format (optional).
    ///   - to: End of date range in ISO 8601 format (optional).
    ///   - cursor: Pagination cursor from a previous response.
    /// - Returns: A paginated response containing calendar events.
    /// - Throws: `PermissionError.calendarDenied` if calendar access is not granted.
    func listEvents(limit: Int, from: String?, to: String?, cursor: String?) async throws -> Page<CalendarEvent>

    /// Searches for events matching a query string.
    /// - Parameters:
    ///   - query: Text to search for in event titles, locations, and notes.
    ///   - limit: Maximum number of events to return.
    ///   - from: Start of date range in ISO 8601 format (optional).
    ///   - to: End of date range in ISO 8601 format (optional).
    ///   - cursor: Pagination cursor from a previous response.
    /// - Returns: A paginated response containing matching events.
    /// - Throws: `PermissionError.calendarDenied` if calendar access is not granted.
    func searchEvents(query: String, limit: Int, from: String?, to: String?, cursor: String?) async throws -> Page<CalendarEvent>

    /// Retrieves a specific event by its identifier.
    /// - Parameter id: Unique identifier of the event.
    /// - Returns: The calendar event.
    /// - Throws: `ValidationError.invalidField` if the event is not found.
    func getEvent(id: String) async throws -> CalendarEvent

    /// Creates a new calendar event.
    /// - Parameters:
    ///   - title: Title of the event.
    ///   - startDate: Start date/time in ISO 8601 format.
    ///   - endDate: End date/time in ISO 8601 format.
    ///   - calendarId: Target calendar identifier (uses default if nil).
    ///   - location: Event location (optional).
    ///   - notes: Event notes (optional).
    /// - Returns: Unique identifier of the created event.
    /// - Throws: `PermissionError.calendarDenied` if calendar access is not granted.
    func createEvent(title: String, startDate: String, endDate: String, calendarId: String?, location: String?, notes: String?) async throws -> String

    /// Updates an existing calendar event.
    /// - Parameters:
    ///   - id: Unique identifier of the event to update.
    ///   - patch: Fields to update (nil fields are left unchanged).
    /// - Returns: The updated event.
    /// - Throws: `ValidationError.invalidField` if the event is not found.
    func updateEvent(id: String, patch: CalendarEventPatch) async throws -> CalendarEvent

    /// Deletes a calendar event.
    /// - Parameter id: Unique identifier of the event to delete.
    /// - Throws: `ValidationError.invalidField` if the event is not found.
    func deleteEvent(id: String) async throws

    /// Opens a calendar event in the Calendar app.
    /// - Parameter id: Unique identifier of the event to open.
    /// - Throws: `ValidationError.invalidField` if the event is not found.
    func openEvent(id: String) async throws
}
