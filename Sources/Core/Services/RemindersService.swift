import Foundation

/// Protocol for interacting with Apple Reminders.
///
/// Defines operations for listing, searching, creating, updating,
/// completing, and deleting reminders. All implementations must be
/// `Sendable` for safe use across actor boundaries.
///
/// ## Example
/// ```swift
/// let service: RemindersService = EventKitRemindersService()
/// let lists = try await service.getLists()
/// ```
public protocol RemindersService: Sendable {

    /// Retrieves all reminder lists.
    /// - Returns: Array of reminder lists.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    func getLists() async throws -> [ReminderList]

    /// Lists reminders in a specific list.
    /// - Parameters:
    ///   - listId: Identifier of the list to query.
    ///   - limit: Maximum number of reminders to return.
    ///   - includeCompleted: Whether to include completed reminders.
    ///   - cursor: Pagination cursor from a previous response.
    /// - Returns: A paginated response containing reminders.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    func list(listId: String, limit: Int, includeCompleted: Bool, cursor: String?) async throws -> Page<Reminder>

    /// Searches for reminders matching a query string.
    /// - Parameters:
    ///   - query: Text to search for in reminder titles and notes.
    ///   - limit: Maximum number of reminders to return.
    ///   - includeCompleted: Whether to include completed reminders.
    ///   - cursor: Pagination cursor from a previous response.
    /// - Returns: A paginated response containing matching reminders.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    func search(query: String, limit: Int, includeCompleted: Bool, cursor: String?) async throws -> Page<Reminder>

    /// Creates a new reminder.
    /// - Parameters:
    ///   - title: Title of the reminder.
    ///   - dueDate: Due date/time in ISO 8601 format (optional).
    ///   - notes: Additional notes (optional).
    ///   - listId: Target list identifier (uses default if nil).
    ///   - priority: Priority level 1-9 (optional).
    /// - Returns: Unique identifier of the created reminder.
    /// - Throws: `PermissionError.remindersDenied` if reminders access is not granted.
    func create(title: String, dueDate: String?, notes: String?, listId: String?, priority: Int?) async throws -> String

    /// Updates an existing reminder.
    /// - Parameters:
    ///   - id: Unique identifier of the reminder to update.
    ///   - patch: Fields to update (nil fields are left unchanged).
    /// - Returns: The updated reminder.
    /// - Throws: `ValidationError.notFound` if the reminder is not found.
    func update(id: String, patch: ReminderPatch) async throws -> Reminder

    /// Deletes a reminder.
    /// - Parameter id: Unique identifier of the reminder to delete.
    /// - Throws: `ValidationError.notFound` if the reminder is not found.
    func delete(id: String) async throws

    /// Marks a reminder as completed.
    /// - Parameter id: Unique identifier of the reminder to complete.
    /// - Returns: The completed reminder.
    /// - Throws: `ValidationError.notFound` if the reminder is not found.
    func complete(id: String) async throws -> Reminder

    /// Opens a reminder in the Reminders app.
    /// - Parameter id: Unique identifier of the reminder to open.
    /// - Throws: `ValidationError.notFound` if the reminder is not found.
    func open(id: String) async throws
}
