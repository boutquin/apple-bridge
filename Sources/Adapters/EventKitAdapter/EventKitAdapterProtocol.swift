import Foundation
import Core

// MARK: - Data Transfer Objects

/// Lightweight data representation of an EventKit event.
///
/// This struct provides a Sendable, Codable representation of calendar events
/// that can be safely passed across actor boundaries without requiring direct
/// EventKit framework access.
public struct EKEventData: Sendable, Equatable {
    /// Unique identifier for the event.
    public let id: String

    /// Title of the event.
    public let title: String

    /// Start date/time of the event.
    public let startDate: Date

    /// End date/time of the event.
    public let endDate: Date

    /// Identifier of the calendar containing this event.
    public let calendarId: String

    /// Location of the event, if specified.
    public let location: String?

    /// Additional notes or description for the event.
    public let notes: String?

    /// Creates a new event data instance.
    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
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

/// Lightweight data representation of an EventKit calendar.
///
/// This struct provides a Sendable representation of calendars that can be
/// safely passed across actor boundaries.
public struct EKCalendarData: Sendable, Equatable {
    /// Unique identifier for the calendar.
    public let id: String

    /// Display title of the calendar.
    public let title: String

    /// Whether the calendar allows modifications.
    public let isWritable: Bool

    /// Creates a new calendar data instance.
    public init(id: String, title: String, isWritable: Bool) {
        self.id = id
        self.title = title
        self.isWritable = isWritable
    }
}

// MARK: - Protocol

/// Protocol for interacting with EventKit for calendar operations.
///
/// This protocol abstracts EventKit operations to enable testing with mock implementations.
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Implementation Notes
/// - Real implementations use EKEventStore for calendar access
/// - Date parameters use Foundation `Date` to preserve timezone information
/// - The protocol uses data transfer objects (EKEventData, EKCalendarData) instead of
///   EKEvent/EKCalendar directly to enable Sendable conformance
///
/// ## Example
/// ```swift
/// let adapter: EventKitAdapterProtocol = RealEventKitAdapter()
/// if try await adapter.requestCalendarAccess() {
///     let events = try await adapter.fetchEvents(from: Date(), to: Date().addingTimeInterval(86400), calendarId: nil)
/// }
/// ```
public protocol EventKitAdapterProtocol: Sendable {

    // MARK: - Authorization

    /// Requests calendar access from the user.
    /// - Returns: `true` if access is granted, `false` if denied.
    /// - Throws: `PermissionError` if there's an issue requesting access.
    func requestCalendarAccess() async throws -> Bool

    // MARK: - Calendar Operations

    /// Fetches all available calendars.
    /// - Returns: Array of calendar data objects.
    /// - Throws: `PermissionError.calendarDenied` if calendar access is not granted.
    func fetchCalendars() async throws -> [EKCalendarData]

    /// Returns the identifier of the default calendar for new events.
    /// - Returns: The default calendar identifier.
    /// - Throws: `PermissionError.calendarDenied` if calendar access is not granted.
    func defaultCalendarId() async throws -> String

    // MARK: - Event Operations

    /// Fetches events within a date range.
    /// - Parameters:
    ///   - from: Start of date range.
    ///   - to: End of date range.
    ///   - calendarId: Optional calendar filter (nil = all calendars).
    /// - Returns: Array of events within the range.
    /// - Throws: `PermissionError.calendarDenied` if calendar access is not granted.
    func fetchEvents(from: Date, to: Date, calendarId: String?) async throws -> [EKEventData]

    /// Fetches a single event by identifier.
    /// - Parameter id: The event identifier.
    /// - Returns: The event data.
    /// - Throws: `ValidationError.notFound` if the event doesn't exist.
    func fetchEvent(id: String) async throws -> EKEventData

    /// Creates a new calendar event.
    /// - Parameters:
    ///   - title: Event title.
    ///   - startDate: Event start date/time.
    ///   - endDate: Event end date/time.
    ///   - calendarId: Target calendar (nil = default calendar).
    ///   - location: Event location (optional).
    ///   - notes: Event notes (optional).
    /// - Returns: The identifier of the created event.
    /// - Throws: `PermissionError.calendarDenied` if calendar access is not granted.
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarId: String?,
        location: String?,
        notes: String?
    ) async throws -> String

    /// Updates an existing calendar event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - title: New title (nil = no change).
    ///   - startDate: New start date (nil = no change).
    ///   - endDate: New end date (nil = no change).
    ///   - location: New location (nil = no change).
    ///   - notes: New notes (nil = no change).
    /// - Returns: The updated event data.
    /// - Throws: `ValidationError.notFound` if the event doesn't exist.
    func updateEvent(
        id: String,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws -> EKEventData

    /// Deletes a calendar event.
    /// - Parameter id: Event identifier.
    /// - Throws: `ValidationError.notFound` if the event doesn't exist.
    func deleteEvent(id: String) async throws

    /// Opens an event in the Calendar app.
    /// - Parameter id: Event identifier.
    /// - Throws: `ValidationError.notFound` if the event doesn't exist.
    func openEvent(id: String) async throws
}
