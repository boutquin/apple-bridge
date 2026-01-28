import Foundation
import Core
import Adapters

/// Mock implementation of `EventKitAdapterProtocol` for testing.
///
/// Provides stubbed data and tracks method calls for verification in tests.
/// All methods are actor-isolated for thread safety.
public actor MockEventKitAdapter: EventKitAdapterProtocol {

    // MARK: - Calendar Stub Data

    /// Whether calendar access is granted.
    private var calendarAccessGranted: Bool = true

    /// Stubbed events to return from fetch operations.
    private var stubEvents: [EKEventData] = []

    /// Stubbed calendars to return from fetch operations.
    private var stubCalendars: [EKCalendarData] = []

    /// Default calendar identifier.
    private var defaultCalendar: String = "default-calendar"

    /// Error to throw (if set) for testing error scenarios.
    private var errorToThrow: (any Error)?

    // MARK: - Calendar Tracking

    /// Tracks events that have been created.
    private var createdEvents: [EKEventData] = []

    /// Tracks IDs of events that have been deleted.
    private var deletedEventIds: [String] = []

    /// Tracks IDs of events that have been opened.
    private var openedEventIds: [String] = []

    // MARK: - Reminders Stub Data

    /// Whether reminders access is granted.
    private var remindersAccessGranted: Bool = true

    /// Stubbed reminders to return from fetch operations.
    private var stubReminders: [EKReminderData] = []

    /// Stubbed reminder lists to return from fetch operations.
    private var stubReminderLists: [EKReminderListData] = []

    /// Default reminder list identifier.
    private var defaultReminderList: String = "default-list"

    // MARK: - Reminders Tracking

    /// Tracks reminders that have been created.
    private var createdReminders: [EKReminderData] = []

    /// Tracks IDs of reminders that have been deleted.
    private var deletedReminderIds: [String] = []

    /// Tracks IDs of reminders that have been opened.
    private var openedReminderIds: [String] = []

    // MARK: - Initialization

    /// Creates a new mock EventKit adapter.
    public init() {}

    // MARK: - Setup Methods

    /// Sets whether calendar access is granted.
    public func setCalendarAccessGranted(_ granted: Bool) {
        self.calendarAccessGranted = granted
    }

    /// Sets stubbed events for testing.
    public func setStubEvents(_ events: [EKEventData]) {
        self.stubEvents = events
    }

    /// Sets stubbed calendars for testing.
    public func setStubCalendars(_ calendars: [EKCalendarData]) {
        self.stubCalendars = calendars
    }

    /// Sets the default calendar identifier.
    public func setDefaultCalendarId(_ id: String) {
        self.defaultCalendar = id
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    // MARK: - Verification Methods

    /// Gets the list of created events for verification.
    public func getCreatedEvents() -> [EKEventData] {
        return createdEvents
    }

    /// Gets the list of deleted event IDs for verification.
    public func getDeletedEventIds() -> [String] {
        return deletedEventIds
    }

    /// Gets the list of opened event IDs for verification.
    public func getOpenedEventIds() -> [String] {
        return openedEventIds
    }

    // MARK: - Reminders Setup Methods

    /// Sets whether reminders access is granted.
    public func setRemindersAccessGranted(_ granted: Bool) {
        self.remindersAccessGranted = granted
    }

    /// Sets stubbed reminders for testing.
    public func setStubReminders(_ reminders: [EKReminderData]) {
        self.stubReminders = reminders
    }

    /// Sets stubbed reminder lists for testing.
    public func setStubReminderLists(_ lists: [EKReminderListData]) {
        self.stubReminderLists = lists
    }

    /// Sets the default reminder list identifier.
    public func setDefaultReminderListId(_ id: String) {
        self.defaultReminderList = id
    }

    // MARK: - Reminders Verification Methods

    /// Gets the list of created reminders for verification.
    public func getCreatedReminders() -> [EKReminderData] {
        return createdReminders
    }

    /// Gets the list of deleted reminder IDs for verification.
    public func getDeletedReminderIds() -> [String] {
        return deletedReminderIds
    }

    /// Gets the list of opened reminder IDs for verification.
    public func getOpenedReminderIds() -> [String] {
        return openedReminderIds
    }

    // MARK: - EventKitAdapterProtocol (Calendar)

    public func requestCalendarAccess() async throws -> Bool {
        if let error = errorToThrow { throw error }
        return calendarAccessGranted
    }

    public func fetchCalendars() async throws -> [EKCalendarData] {
        if let error = errorToThrow { throw error }
        return stubCalendars
    }

    public func defaultCalendarId() async throws -> String {
        if let error = errorToThrow { throw error }
        return defaultCalendar
    }

    public func fetchEvents(from: Date, to: Date, calendarId: String?) async throws -> [EKEventData] {
        if let error = errorToThrow { throw error }

        // Filter by date range and optionally by calendar
        return stubEvents.filter { event in
            let inRange = event.startDate >= from && event.startDate <= to
            let matchesCalendar = calendarId == nil || event.calendarId == calendarId
            return inRange && matchesCalendar
        }
    }

    public func fetchEvent(id: String) async throws -> EKEventData {
        if let error = errorToThrow { throw error }

        guard let event = stubEvents.first(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Event", id: id)
        }

        return event
    }

    public func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarId: String?,
        location: String?,
        notes: String?
    ) async throws -> String {
        if let error = errorToThrow { throw error }

        let id = UUID().uuidString
        let event = EKEventData(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            calendarId: calendarId ?? defaultCalendar,
            location: location,
            notes: notes
        )

        createdEvents.append(event)
        stubEvents.append(event)

        return id
    }

    public func updateEvent(
        id: String,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws -> EKEventData {
        if let error = errorToThrow { throw error }

        guard let index = stubEvents.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Event", id: id)
        }

        let existing = stubEvents[index]

        // Apply updates (non-nil values override existing)
        let updated = EKEventData(
            id: existing.id,
            title: title ?? existing.title,
            startDate: startDate ?? existing.startDate,
            endDate: endDate ?? existing.endDate,
            calendarId: existing.calendarId,
            location: location ?? existing.location,
            notes: notes ?? existing.notes
        )

        stubEvents[index] = updated
        return updated
    }

    public func deleteEvent(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard let index = stubEvents.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Event", id: id)
        }

        stubEvents.remove(at: index)
        deletedEventIds.append(id)
    }

    public func openEvent(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard stubEvents.contains(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Event", id: id)
        }

        openedEventIds.append(id)
    }

    // MARK: - EventKitAdapterProtocol (Reminders)

    public func requestRemindersAccess() async throws -> Bool {
        if let error = errorToThrow { throw error }
        return remindersAccessGranted
    }

    public func fetchReminderLists() async throws -> [EKReminderListData] {
        if let error = errorToThrow { throw error }
        return stubReminderLists
    }

    public func defaultReminderListId() async throws -> String {
        if let error = errorToThrow { throw error }
        return defaultReminderList
    }

    public func fetchReminders(listId: String?, includeCompleted: Bool) async throws -> [EKReminderData] {
        if let error = errorToThrow { throw error }

        // Filter by list if specified
        var filtered = stubReminders
        if let listId {
            filtered = filtered.filter { $0.listId == listId }
        }

        // Filter by completion status
        if !includeCompleted {
            filtered = filtered.filter { !$0.isCompleted }
        }

        return filtered
    }

    public func fetchReminder(id: String) async throws -> EKReminderData {
        if let error = errorToThrow { throw error }

        guard let reminder = stubReminders.first(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        return reminder
    }

    public func createReminder(
        title: String,
        dueDate: Date?,
        notes: String?,
        listId: String?,
        priority: Int?
    ) async throws -> String {
        if let error = errorToThrow { throw error }

        let id = UUID().uuidString
        let reminder = EKReminderData(
            id: id,
            title: title,
            listId: listId ?? defaultReminderList,
            isCompleted: false,
            dueDate: dueDate,
            notes: notes,
            priority: priority
        )

        createdReminders.append(reminder)
        stubReminders.append(reminder)

        return id
    }

    public func updateReminder(
        id: String,
        title: String?,
        dueDate: Date?,
        notes: String?,
        listId: String?,
        priority: Int?
    ) async throws -> EKReminderData {
        if let error = errorToThrow { throw error }

        guard let index = stubReminders.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        let existing = stubReminders[index]

        // Apply updates (non-nil values override existing)
        let updated = EKReminderData(
            id: existing.id,
            title: title ?? existing.title,
            listId: listId ?? existing.listId,
            isCompleted: existing.isCompleted,
            dueDate: dueDate ?? existing.dueDate,
            notes: notes ?? existing.notes,
            priority: priority ?? existing.priority
        )

        stubReminders[index] = updated
        return updated
    }

    public func deleteReminder(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard let index = stubReminders.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        stubReminders.remove(at: index)
        deletedReminderIds.append(id)
    }

    public func completeReminder(id: String) async throws -> EKReminderData {
        if let error = errorToThrow { throw error }

        guard let index = stubReminders.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        let existing = stubReminders[index]

        // Mark as completed
        let completed = EKReminderData(
            id: existing.id,
            title: existing.title,
            listId: existing.listId,
            isCompleted: true,
            dueDate: existing.dueDate,
            notes: existing.notes,
            priority: existing.priority
        )

        stubReminders[index] = completed
        return completed
    }

    public func openReminder(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard stubReminders.contains(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        openedReminderIds.append(id)
    }
}
