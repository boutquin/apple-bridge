import Foundation
import Core

/// Mock implementation of `RemindersService` for testing.
///
/// Provides stubbed data and tracks method calls for verification in tests.
/// All methods are actor-isolated for thread safety.
public actor MockRemindersService: RemindersService {

    /// Stubbed reminder lists to return.
    public var stubLists: [ReminderList] = []

    /// Stubbed reminders to return from list and search operations.
    public var stubReminders: [Reminder] = []

    /// Tracks reminders that have been created.
    public var createdReminders: [Reminder] = []

    /// Tracks IDs of reminders that have been deleted.
    public var deletedReminderIds: [String] = []

    /// Tracks IDs of reminders that have been opened.
    public var openedReminderIds: [String] = []

    /// Error to throw (if set) for testing error scenarios.
    public var errorToThrow: (any Error)?

    /// Creates a new mock reminders service.
    public init() {}

    /// Sets stubbed reminder lists for testing.
    public func setStubLists(_ lists: [ReminderList]) {
        self.stubLists = lists
    }

    /// Sets stubbed reminders for testing.
    public func setStubReminders(_ reminders: [Reminder]) {
        self.stubReminders = reminders
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    public func getLists() async throws -> [ReminderList] {
        if let error = errorToThrow { throw error }
        return stubLists
    }

    public func list(listId: String, limit: Int, includeCompleted: Bool, cursor: String?) async throws -> Page<Reminder> {
        if let error = errorToThrow { throw error }

        // Filter by listId and completion status
        var filtered = stubReminders.filter { $0.listId == listId }
        if !includeCompleted {
            filtered = filtered.filter { !$0.isCompleted }
        }

        // Apply limit
        let limitedReminders = Array(filtered.prefix(limit))
        let hasMore = filtered.count > limit
        let nextCursor = hasMore ? "mock-cursor-\(limit)" : nil

        return Page(items: limitedReminders, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func search(query: String, limit: Int, includeCompleted: Bool, cursor: String?) async throws -> Page<Reminder> {
        if let error = errorToThrow { throw error }

        // Filter by query (case-insensitive search in title and notes)
        var filtered = stubReminders.filter { reminder in
            reminder.title.localizedCaseInsensitiveContains(query) ||
            (reminder.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }

        if !includeCompleted {
            filtered = filtered.filter { !$0.isCompleted }
        }

        let limitedReminders = Array(filtered.prefix(limit))
        let hasMore = filtered.count > limit
        let nextCursor = hasMore ? "mock-cursor-\(limit)" : nil

        return Page(items: limitedReminders, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func create(title: String, dueDate: String?, notes: String?, listId: String?, priority: Int?) async throws -> String {
        if let error = errorToThrow { throw error }

        let id = UUID().uuidString
        let reminder = Reminder(
            id: id,
            title: title,
            dueDate: dueDate,
            notes: notes,
            isCompleted: false,
            listId: listId ?? "default-list",
            priority: priority
        )

        createdReminders.append(reminder)
        stubReminders.append(reminder)

        return id
    }

    public func update(id: String, patch: ReminderPatch) async throws -> Reminder {
        if let error = errorToThrow { throw error }

        guard let index = stubReminders.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        let existing = stubReminders[index]

        // Apply patch (non-nil fields override existing values)
        let updated = Reminder(
            id: existing.id,
            title: patch.title ?? existing.title,
            dueDate: patch.dueDate ?? existing.dueDate,
            notes: patch.notes ?? existing.notes,
            isCompleted: existing.isCompleted,
            listId: patch.listId ?? existing.listId,
            priority: patch.priority ?? existing.priority
        )

        stubReminders[index] = updated
        return updated
    }

    public func delete(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard let index = stubReminders.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        stubReminders.remove(at: index)
        deletedReminderIds.append(id)
    }

    public func complete(id: String) async throws -> Reminder {
        if let error = errorToThrow { throw error }

        guard let index = stubReminders.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        let existing = stubReminders[index]

        // Mark as completed
        let completed = Reminder(
            id: existing.id,
            title: existing.title,
            dueDate: existing.dueDate,
            notes: existing.notes,
            isCompleted: true,
            listId: existing.listId,
            priority: existing.priority
        )

        stubReminders[index] = completed
        return completed
    }

    public func open(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard stubReminders.contains(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Reminder", id: id)
        }

        openedReminderIds.append(id)
    }
}
