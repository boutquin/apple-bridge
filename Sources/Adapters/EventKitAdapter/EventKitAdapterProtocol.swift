import Foundation
import Core

// MARK: - Calendar Data Transfer Objects

/// Lightweight data representation of a calendar event.
///
/// This struct provides a Sendable, Codable representation of calendar events
/// that can be safely passed across actor boundaries without requiring direct
/// framework access. Used as the boundary type between adapter implementations
/// (EventKit, AppleScript, etc.) and the service layer.
public struct CalendarEventData: Sendable, Equatable {
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

/// Lightweight data representation of a calendar.
///
/// This struct provides a Sendable representation of calendars that can be
/// safely passed across actor boundaries. Used as the boundary type between
/// adapter implementations and the service layer.
public struct CalendarData: Sendable, Equatable {
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

// MARK: - Reminders Data Transfer Objects

/// Lightweight data representation of a reminder.
///
/// This struct provides a Sendable, Codable representation of reminders
/// that can be safely passed across actor boundaries without requiring direct
/// framework access. Used as the boundary type between adapter implementations
/// (EventKit, AppleScript, etc.) and the service layer.
public struct ReminderData: Sendable, Equatable {
    /// Unique identifier for the reminder.
    public let id: String

    /// Title of the reminder.
    public let title: String

    /// Identifier of the list containing this reminder.
    public let listId: String

    /// Whether the reminder has been completed.
    public let isCompleted: Bool

    /// Due date/time of the reminder, if set.
    public let dueDate: Date?

    /// Additional notes for the reminder.
    public let notes: String?

    /// Priority level (1 = high, 5 = medium, 9 = low), or `nil` for none.
    public let priority: Int?

    /// Creates a new reminder data instance.
    public init(
        id: String,
        title: String,
        listId: String,
        isCompleted: Bool,
        dueDate: Date? = nil,
        notes: String? = nil,
        priority: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.listId = listId
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.notes = notes
        self.priority = priority
    }
}

/// Lightweight data representation of a reminder list.
///
/// This struct provides a Sendable representation of reminder lists that can be
/// safely passed across actor boundaries. Used as the boundary type between
/// adapter implementations and the service layer.
public struct ReminderListData: Sendable, Equatable {
    /// Unique identifier for the list.
    public let id: String

    /// Display name of the list.
    public let name: String

    /// Creates a new reminder list data instance.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Protocol

/// Protocol for interacting with Apple Calendar and Reminders.
///
/// This protocol abstracts calendar and reminders operations to enable testing with mock
/// implementations and to support multiple backend implementations (EventKit, AppleScript, etc.).
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Implementation Notes
/// - EventKit implementation uses EKEventStore for calendar access
/// - AppleScript implementation uses osascript for calendar access
/// - Date parameters use Foundation `Date` to preserve timezone information
/// - The protocol uses generic data transfer objects (CalendarEventData, CalendarData) to
///   decouple from specific framework types
///
/// ## Example
/// ```swift
/// let adapter: CalendarAdapterProtocol = RealEventKitAdapter()
/// if try await adapter.requestCalendarAccess() {
///     let events = try await adapter.fetchEvents(from: Date(), to: Date().addingTimeInterval(86400), calendarId: nil)
/// }
/// ```
public protocol CalendarAdapterProtocol: Sendable {

    // MARK: - Authorization

    /// Requests calendar access from the user.
    /// - Returns: `true` if access is granted, `false` if denied.
    /// - Throws: `PermissionError` if there's an issue requesting access.
    func requestCalendarAccess() async throws -> Bool

    // MARK: - Calendar Operations

    /// Fetches all available calendars.
    /// - Returns: Array of calendar data objects.
    /// - Throws: `PermissionError.calendarDenied` if calendar access is not granted.
    func fetchCalendars() async throws -> [CalendarData]

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
    func fetchEvents(from: Date, to: Date, calendarId: String?) async throws -> [CalendarEventData]

    /// Fetches a single event by identifier.
    /// - Parameter id: The event identifier.
    /// - Returns: The event data.
    /// - Throws: `ValidationError.notFound` if the event doesn't exist.
    func fetchEvent(id: String) async throws -> CalendarEventData

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
    ) async throws -> CalendarEventData

    /// Deletes a calendar event.
    /// - Parameter id: Event identifier.
    /// - Throws: `ValidationError.notFound` if the event doesn't exist.
    func deleteEvent(id: String) async throws

    /// Opens an event in the Calendar app.
    /// - Parameter id: Event identifier.
    /// - Throws: `ValidationError.notFound` if the event doesn't exist.
    func openEvent(id: String) async throws

    // MARK: - Reminders Authorization

    /// Requests reminders access from the user.
    /// - Returns: `true` if access is granted, `false` if denied.
    /// - Throws: `PermissionError` if there's an issue requesting access.
    func requestRemindersAccess() async throws -> Bool

    // MARK: - Reminder List Operations

    /// Fetches all reminder lists.
    /// - Returns: Array of reminder list data objects.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    func fetchReminderLists() async throws -> [ReminderListData]

    /// Returns the identifier of the default reminder list.
    /// - Returns: The default list identifier.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    func defaultReminderListId() async throws -> String

    // MARK: - Reminder Operations

    /// Fetches reminders from a specific list.
    /// - Parameters:
    ///   - listId: The list identifier (nil = all lists).
    ///   - includeCompleted: Whether to include completed reminders.
    /// - Returns: Array of reminders.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    func fetchReminders(listId: String?, includeCompleted: Bool) async throws -> [ReminderData]

    /// Fetches a single reminder by identifier.
    /// - Parameter id: The reminder identifier.
    /// - Returns: The reminder data.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    func fetchReminder(id: String) async throws -> ReminderData

    /// Creates a new reminder.
    /// - Parameters:
    ///   - title: Reminder title.
    ///   - dueDate: Due date/time (optional).
    ///   - notes: Reminder notes (optional).
    ///   - listId: Target list (nil = default list).
    ///   - priority: Priority 1-9 (optional).
    /// - Returns: The identifier of the created reminder.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    func createReminder(
        title: String,
        dueDate: Date?,
        notes: String?,
        listId: String?,
        priority: Int?
    ) async throws -> String

    /// Updates an existing reminder.
    /// - Parameters:
    ///   - id: Reminder identifier.
    ///   - title: New title (nil = no change).
    ///   - dueDate: New due date (nil = no change).
    ///   - notes: New notes (nil = no change).
    ///   - listId: New list ID (nil = no change).
    ///   - priority: New priority (nil = no change).
    /// - Returns: The updated reminder data.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    func updateReminder(
        id: String,
        title: String?,
        dueDate: Date?,
        notes: String?,
        listId: String?,
        priority: Int?
    ) async throws -> ReminderData

    /// Deletes a reminder.
    /// - Parameter id: Reminder identifier.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    func deleteReminder(id: String) async throws

    /// Marks a reminder as completed.
    /// - Parameter id: Reminder identifier.
    /// - Returns: The completed reminder data.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    func completeReminder(id: String) async throws -> ReminderData

    /// Opens a reminder in the Reminders app.
    /// - Parameter id: Reminder identifier.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    func openReminder(id: String) async throws
}
