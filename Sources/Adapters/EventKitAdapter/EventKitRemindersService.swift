import Foundation
import Core

/// Implementation of `RemindersService` using EventKit via an adapter.
///
/// This service translates between the high-level `RemindersService` protocol
/// (using ISO 8601 string dates) and the lower-level `CalendarAdapterProtocol`
/// (using Foundation `Date` objects).
///
/// ## Example
/// ```swift
/// let adapter = RealEventKitAdapter()
/// let service = EventKitRemindersService(adapter: adapter)
/// let lists = try await service.getLists()
/// ```
public struct EventKitRemindersService: RemindersService, Sendable {

    /// The adapter used to interact with reminders backend.
    private let adapter: any CalendarAdapterProtocol

    /// Creates a new reminders service with the given adapter.
    /// - Parameter adapter: The calendar adapter to use for reminder operations.
    public init(adapter: any CalendarAdapterProtocol) {
        self.adapter = adapter
    }

    // MARK: - RemindersService Protocol

    /// Retrieves all reminder lists.
    /// - Returns: Array of `ReminderList` objects.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    public func getLists() async throws -> [ReminderList] {
        let ekLists = try await adapter.fetchReminderLists()
        return ekLists.map { ReminderList(id: $0.id, name: $0.name) }
    }

    /// Lists reminders in a specific list with pagination.
    /// - Parameters:
    ///   - listId: Identifier of the reminder list to query.
    ///   - limit: Maximum number of reminders to return per page.
    ///   - includeCompleted: Whether to include completed reminders.
    ///   - cursor: Pagination cursor from a previous response (nil for first page).
    /// - Returns: A paginated `Page<Reminder>` with items and optional `nextCursor`.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    public func list(listId: String, limit: Int, includeCompleted: Bool, cursor: String?) async throws -> Page<Reminder> {
        let allReminders = try await adapter.fetchReminders(listId: listId, includeCompleted: includeCompleted)

        // Apply cursor-based pagination
        let startIndex = decodeCursorOffset(cursor)
        let paginatedReminders = Array(allReminders.dropFirst(startIndex))
        let limitedReminders = Array(paginatedReminders.prefix(limit))
        let hasMore = paginatedReminders.count > limit

        let items = limitedReminders.map(convertToReminder)
        let nextCursor = hasMore ? encodeCursor(offset: startIndex + limit) : nil

        return Page(items: items, nextCursor: nextCursor, hasMore: hasMore)
    }

    /// Searches reminders across all lists by query string.
    ///
    /// Performs case-insensitive search in reminder titles and notes.
    ///
    /// - Parameters:
    ///   - query: Search query string.
    ///   - limit: Maximum number of reminders to return per page.
    ///   - includeCompleted: Whether to include completed reminders in results.
    ///   - cursor: Pagination cursor from a previous response (nil for first page).
    /// - Returns: A paginated `Page<Reminder>` with matching items.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    public func search(query: String, limit: Int, includeCompleted: Bool, cursor: String?) async throws -> Page<Reminder> {
        // Fetch all reminders from all lists
        let allReminders = try await adapter.fetchReminders(listId: nil, includeCompleted: includeCompleted)

        // Filter by query (case-insensitive search in title and notes)
        let filtered = allReminders.filter { reminder in
            reminder.title.localizedCaseInsensitiveContains(query) ||
            (reminder.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }

        // Apply cursor-based pagination
        let startIndex = decodeCursorOffset(cursor)
        let paginatedReminders = Array(filtered.dropFirst(startIndex))
        let limitedReminders = Array(paginatedReminders.prefix(limit))
        let hasMore = paginatedReminders.count > limit

        let items = limitedReminders.map(convertToReminder)
        let nextCursor = hasMore ? encodeCursor(offset: startIndex + limit) : nil

        return Page(items: items, nextCursor: nextCursor, hasMore: hasMore)
    }

    /// Creates a new reminder.
    /// - Parameters:
    ///   - title: Title of the reminder (required).
    ///   - dueDate: Due date in ISO 8601 format (optional).
    ///   - notes: Additional notes (optional).
    ///   - listId: Target list identifier (nil uses default list).
    ///   - priority: Priority level 1-9 where 1 is highest (optional).
    /// - Returns: The identifier of the created reminder.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    public func create(title: String, dueDate: String?, notes: String?, listId: String?, priority: Int?) async throws -> String {
        let dueDateParsed: Date? = dueDate.flatMap { parseDate($0) }

        return try await adapter.createReminder(
            title: title,
            dueDate: dueDateParsed,
            notes: notes,
            listId: listId,
            priority: priority
        )
    }

    /// Updates an existing reminder.
    ///
    /// Only fields present in the patch are updated; other fields remain unchanged.
    ///
    /// - Parameters:
    ///   - id: Identifier of the reminder to update.
    ///   - patch: Fields to update (nil values are ignored).
    /// - Returns: The updated `Reminder`.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    public func update(id: String, patch: ReminderPatch) async throws -> Reminder {
        let dueDateParsed: Date? = patch.dueDate.flatMap { parseDate($0) }

        let updated = try await adapter.updateReminder(
            id: id,
            title: patch.title,
            dueDate: dueDateParsed,
            notes: patch.notes,
            listId: patch.listId,
            priority: patch.priority
        )

        return convertToReminder(updated)
    }

    /// Deletes a reminder.
    /// - Parameter id: Identifier of the reminder to delete.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    public func delete(id: String) async throws {
        try await adapter.deleteReminder(id: id)
    }

    /// Marks a reminder as completed.
    /// - Parameter id: Identifier of the reminder to complete.
    /// - Returns: The updated `Reminder` with `isCompleted` set to `true`.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    public func complete(id: String) async throws -> Reminder {
        let completed = try await adapter.completeReminder(id: id)
        return convertToReminder(completed)
    }

    /// Opens a reminder in the Reminders app.
    /// - Parameter id: Identifier of the reminder to open.
    /// - Throws: `ValidationError.notFound` if the reminder doesn't exist.
    public func open(id: String) async throws {
        try await adapter.openReminder(id: id)
    }

    // MARK: - Private Helpers

    /// Converts a `ReminderData` to a `Reminder`.
    private func convertToReminder(_ reminder: ReminderData) -> Reminder {
        Reminder(
            id: reminder.id,
            title: reminder.title,
            dueDate: reminder.dueDate.map { formatDate($0) },
            notes: reminder.notes,
            isCompleted: reminder.isCompleted,
            listId: reminder.listId,
            priority: reminder.priority
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
    /// - Parameter dateString: The date string to parse.
    /// - Returns: The parsed Date, or nil if the string was invalid.
    /// - Note: Creates new formatters each call to be Sendable-safe.
    private func parseDate(_ dateString: String) -> Date? {
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
