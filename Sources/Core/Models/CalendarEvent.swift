import Foundation

/// A calendar event from Apple Calendar.
///
/// Represents a single event with its associated metadata. Dates are stored
/// as ISO 8601 strings for JSON serialization compatibility.
///
/// ## Example
/// ```swift
/// let event = CalendarEvent(
///     id: "E123",
///     title: "Team Meeting",
///     startDate: "2024-01-28T10:00:00Z",
///     endDate: "2024-01-28T11:00:00Z",
///     calendarId: "work",
///     location: "Conference Room A"
/// )
/// ```
public struct CalendarEvent: Codable, Sendable, Equatable {
    /// Unique identifier for the event.
    public let id: String

    /// Title of the event.
    public let title: String

    /// Start date/time in ISO 8601 format.
    public let startDate: String

    /// End date/time in ISO 8601 format.
    public let endDate: String

    /// Identifier of the calendar containing this event.
    public let calendarId: String

    /// Location of the event, if specified.
    public let location: String?

    /// Additional notes or description for the event.
    public let notes: String?

    /// Creates a new calendar event.
    /// - Parameters:
    ///   - id: Unique identifier for the event.
    ///   - title: Title of the event.
    ///   - startDate: Start date/time in ISO 8601 format.
    ///   - endDate: End date/time in ISO 8601 format.
    ///   - calendarId: Identifier of the calendar containing this event.
    ///   - location: Location of the event.
    ///   - notes: Additional notes or description.
    public init(
        id: String,
        title: String,
        startDate: String,
        endDate: String,
        calendarId: String,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarId = calendarId
        self.location = location
        self.notes = notes
    }
}

/// A patch model for updating calendar events.
///
/// Only non-nil fields will be updated when applying this patch.
/// Pass `nil` for any field that should remain unchanged.
///
/// ## Example
/// ```swift
/// let patch = CalendarEventPatch(
///     title: "Updated Meeting",
///     location: "Room B"
/// )
/// ```
public struct CalendarEventPatch: Codable, Sendable, Equatable {
    /// New title, or `nil` to keep existing.
    public let title: String?

    /// New start date/time in ISO 8601 format, or `nil` to keep existing.
    public let startDate: String?

    /// New end date/time in ISO 8601 format, or `nil` to keep existing.
    public let endDate: String?

    /// New location, or `nil` to keep existing.
    public let location: String?

    /// New notes, or `nil` to keep existing.
    public let notes: String?

    /// Creates a patch for updating a calendar event.
    /// - Parameters:
    ///   - title: New title, or `nil` to keep existing.
    ///   - startDate: New start date/time, or `nil` to keep existing.
    ///   - endDate: New end date/time, or `nil` to keep existing.
    ///   - location: New location, or `nil` to keep existing.
    ///   - notes: New notes, or `nil` to keep existing.
    public init(
        title: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
    }
}
