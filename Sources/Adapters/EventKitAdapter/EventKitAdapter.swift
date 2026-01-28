import Foundation
import Core

#if canImport(EventKit)
import EventKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// EventKit implementation of `CalendarAdapterProtocol`.
///
/// This adapter provides actual access to the user's calendar and reminders
/// through Apple's EventKit framework.
///
/// ## Usage
/// ```swift
/// let adapter = EventKitAdapter()
/// if try await adapter.requestCalendarAccess() {
///     let events = try await adapter.fetchEvents(from: Date(), to: Date().addingTimeInterval(86400), calendarId: nil)
/// }
/// ```
///
/// ## Requirements
/// - macOS 10.15+ (uses modern async/await APIs)
/// - Calendar and Reminders permissions must be granted by the user
public actor EventKitAdapter: CalendarAdapterProtocol {

    #if canImport(EventKit)
    /// Shared event store for calendar and reminders access.
    /// Marked nonisolated(unsafe) because EKEventStore handles its own thread safety
    /// and Swift 6's strict concurrency checking doesn't recognize this.
    private nonisolated(unsafe) let eventStore = EKEventStore()
    #endif

    /// Creates a new EventKit adapter.
    public init() {}

    // MARK: - Calendar Authorization

    public func requestCalendarAccess() async throws -> Bool {
        #if canImport(EventKit)
        if #available(macOS 14.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    // MARK: - Calendar Operations

    public func fetchCalendars() async throws -> [CalendarData] {
        #if canImport(EventKit)
        let calendars = eventStore.calendars(for: .event)
        return calendars.map { cal in
            CalendarData(
                id: cal.calendarIdentifier,
                title: cal.title,
                isWritable: cal.allowsContentModifications
            )
        }
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    public func defaultCalendarId() async throws -> String {
        #if canImport(EventKit)
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw ValidationError.notFound(resource: "calendar", id: "default")
        }
        return calendar.calendarIdentifier
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    public func fetchEvents(from: Date, to: Date, calendarId: String?) async throws -> [CalendarEventData] {
        #if canImport(EventKit)
        let calendars: [EKCalendar]?
        if let calId = calendarId {
            if let calendar = eventStore.calendar(withIdentifier: calId) {
                calendars = [calendar]
            } else {
                throw ValidationError.notFound(resource: "calendar", id: calId)
            }
        } else {
            calendars = nil
        }

        let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        return events.map { event in
            CalendarEventData(
                id: event.eventIdentifier,
                title: event.title ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarId: event.calendar.calendarIdentifier,
                location: event.location,
                notes: event.notes
            )
        }
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    public func fetchEvent(id: String) async throws -> CalendarEventData {
        #if canImport(EventKit)
        guard let event = eventStore.event(withIdentifier: id) else {
            throw ValidationError.notFound(resource: "event", id: id)
        }
        return CalendarEventData(
            id: event.eventIdentifier,
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            calendarId: event.calendar.calendarIdentifier,
            location: event.location,
            notes: event.notes
        )
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    public func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarId: String?,
        location: String?,
        notes: String?
    ) async throws -> String {
        #if canImport(EventKit)
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate

        if let calId = calendarId {
            guard let calendar = eventStore.calendar(withIdentifier: calId) else {
                throw ValidationError.notFound(resource: "calendar", id: calId)
            }
            event.calendar = calendar
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        event.location = location
        event.notes = notes

        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    public func updateEvent(
        id: String,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws -> CalendarEventData {
        #if canImport(EventKit)
        guard let event = eventStore.event(withIdentifier: id) else {
            throw ValidationError.notFound(resource: "event", id: id)
        }

        if let title = title { event.title = title }
        if let start = startDate { event.startDate = start }
        if let end = endDate { event.endDate = end }
        if let loc = location { event.location = loc }
        if let n = notes { event.notes = n }

        try eventStore.save(event, span: .thisEvent)

        return CalendarEventData(
            id: event.eventIdentifier,
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            calendarId: event.calendar.calendarIdentifier,
            location: event.location,
            notes: event.notes
        )
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    public func deleteEvent(id: String) async throws {
        #if canImport(EventKit)
        guard let event = eventStore.event(withIdentifier: id) else {
            throw ValidationError.notFound(resource: "event", id: id)
        }
        try eventStore.remove(event, span: .thisEvent)
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    public func openEvent(id: String) async throws {
        #if canImport(EventKit) && canImport(AppKit)
        guard eventStore.event(withIdentifier: id) != nil else {
            throw ValidationError.notFound(resource: "event", id: id)
        }
        // Open Calendar app to the event date
        guard let url = URL(string: "ical://") else {
            throw ValidationError.invalidFormat(field: "url", expected: "valid URL scheme")
        }
        NSWorkspace.shared.open(url)
        #else
        throw PermissionError.calendarDenied
        #endif
    }

    // MARK: - Reminders Authorization

    public func requestRemindersAccess() async throws -> Bool {
        #if canImport(EventKit)
        if #available(macOS 14.0, *) {
            return try await eventStore.requestFullAccessToReminders()
        } else {
            return try await eventStore.requestAccess(to: .reminder)
        }
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    // MARK: - Reminder List Operations

    public func fetchReminderLists() async throws -> [ReminderListData] {
        #if canImport(EventKit)
        let calendars = eventStore.calendars(for: .reminder)
        return calendars.map { cal in
            ReminderListData(id: cal.calendarIdentifier, name: cal.title)
        }
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    public func defaultReminderListId() async throws -> String {
        #if canImport(EventKit)
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw ValidationError.notFound(resource: "reminderList", id: "default")
        }
        return calendar.calendarIdentifier
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    // MARK: - Reminder Operations

    public func fetchReminders(listId: String?, includeCompleted: Bool) async throws -> [ReminderData] {
        #if canImport(EventKit)
        let calendars: [EKCalendar]?
        if let listId = listId {
            if let calendar = eventStore.calendar(withIdentifier: listId) {
                calendars = [calendar]
            } else {
                throw ValidationError.notFound(resource: "reminderList", id: listId)
            }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }

        let predicate = eventStore.predicateForReminders(in: calendars)

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders else {
                    continuation.resume(throwing: PermissionError.remindersDenied)
                    return
                }

                let filtered = includeCompleted ? reminders : reminders.filter { !$0.isCompleted }

                let data = filtered.map { reminder in
                    ReminderData(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "",
                        listId: reminder.calendar.calendarIdentifier,
                        isCompleted: reminder.isCompleted,
                        dueDate: reminder.dueDateComponents?.date,
                        notes: reminder.notes,
                        priority: reminder.priority == 0 ? nil : reminder.priority
                    )
                }
                continuation.resume(returning: data)
            }
        }
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    public func fetchReminder(id: String) async throws -> ReminderData {
        #if canImport(EventKit)
        guard let item = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ValidationError.notFound(resource: "reminder", id: id)
        }
        return ReminderData(
            id: item.calendarItemIdentifier,
            title: item.title ?? "",
            listId: item.calendar.calendarIdentifier,
            isCompleted: item.isCompleted,
            dueDate: item.dueDateComponents?.date,
            notes: item.notes,
            priority: item.priority == 0 ? nil : item.priority
        )
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    public func createReminder(
        title: String,
        dueDate: Date?,
        notes: String?,
        listId: String?,
        priority: Int?
    ) async throws -> String {
        #if canImport(EventKit)
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes

        if let listId = listId {
            guard let calendar = eventStore.calendar(withIdentifier: listId) else {
                throw ValidationError.notFound(resource: "reminderList", id: listId)
            }
            reminder.calendar = calendar
        } else {
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
        }

        if let due = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
        }

        if let priority = priority {
            reminder.priority = priority
        }

        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    public func updateReminder(
        id: String,
        title: String?,
        dueDate: Date?,
        notes: String?,
        listId: String?,
        priority: Int?
    ) async throws -> ReminderData {
        #if canImport(EventKit)
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ValidationError.notFound(resource: "reminder", id: id)
        }

        if let title = title { reminder.title = title }
        if let notes = notes { reminder.notes = notes }
        if let priority = priority { reminder.priority = priority }

        if let due = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
        }

        // Move to different list if specified
        if let listId = listId {
            guard let calendar = eventStore.calendar(withIdentifier: listId) else {
                throw ValidationError.notFound(resource: "reminderList", id: listId)
            }
            reminder.calendar = calendar
        }

        try eventStore.save(reminder, commit: true)

        return ReminderData(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            listId: reminder.calendar.calendarIdentifier,
            isCompleted: reminder.isCompleted,
            dueDate: reminder.dueDateComponents?.date,
            notes: reminder.notes,
            priority: reminder.priority == 0 ? nil : reminder.priority
        )
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    public func deleteReminder(id: String) async throws {
        #if canImport(EventKit)
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ValidationError.notFound(resource: "reminder", id: id)
        }
        try eventStore.remove(reminder, commit: true)
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    public func completeReminder(id: String) async throws -> ReminderData {
        #if canImport(EventKit)
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ValidationError.notFound(resource: "reminder", id: id)
        }
        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)

        return ReminderData(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            listId: reminder.calendar.calendarIdentifier,
            isCompleted: reminder.isCompleted,
            dueDate: reminder.dueDateComponents?.date,
            notes: reminder.notes,
            priority: reminder.priority == 0 ? nil : reminder.priority
        )
        #else
        throw PermissionError.remindersDenied
        #endif
    }

    public func openReminder(id: String) async throws {
        #if canImport(EventKit) && canImport(AppKit)
        guard eventStore.calendarItem(withIdentifier: id) as? EKReminder != nil else {
            throw ValidationError.notFound(resource: "reminder", id: id)
        }
        // Open Reminders app
        guard let url = URL(string: "x-apple-reminderkit://") else {
            throw ValidationError.invalidFormat(field: "url", expected: "valid URL scheme")
        }
        NSWorkspace.shared.open(url)
        #else
        throw PermissionError.remindersDenied
        #endif
    }
}
