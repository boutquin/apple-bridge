import Foundation

/// A reminder from Apple Reminders.
///
/// Represents a single reminder item with its completion status, due date,
/// and associated metadata.
///
/// ## Example
/// ```swift
/// let reminder = Reminder(
///     id: "R123",
///     title: "Buy groceries",
///     dueDate: "2024-01-28T17:00:00Z",
///     isCompleted: false,
///     listId: "shopping",
///     priority: 1
/// )
/// ```
public struct Reminder: Codable, Sendable, Equatable {
    /// Unique identifier for the reminder.
    public let id: String

    /// Title of the reminder.
    public let title: String

    /// Due date/time in ISO 8601 format, if set.
    public let dueDate: String?

    /// Additional notes for the reminder.
    public let notes: String?

    /// Whether the reminder has been completed.
    public let isCompleted: Bool

    /// Identifier of the list containing this reminder.
    public let listId: String

    /// Priority level (1 = high, 5 = medium, 9 = low), or `nil` for none.
    public let priority: Int?

    /// Creates a new reminder.
    /// - Parameters:
    ///   - id: Unique identifier for the reminder.
    ///   - title: Title of the reminder.
    ///   - dueDate: Due date/time in ISO 8601 format.
    ///   - notes: Additional notes.
    ///   - isCompleted: Whether the reminder is completed.
    ///   - listId: Identifier of the containing list.
    ///   - priority: Priority level (1 = high, 5 = medium, 9 = low).
    public init(
        id: String,
        title: String,
        dueDate: String? = nil,
        notes: String? = nil,
        isCompleted: Bool,
        listId: String,
        priority: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.notes = notes
        self.isCompleted = isCompleted
        self.listId = listId
        self.priority = priority
    }
}

/// A reminder list from Apple Reminders.
///
/// Represents a collection of reminders grouped under a common name.
public struct ReminderList: Codable, Sendable, Equatable {
    /// Unique identifier for the list.
    public let id: String

    /// Display name of the list.
    public let name: String

    /// Creates a new reminder list.
    /// - Parameters:
    ///   - id: Unique identifier for the list.
    ///   - name: Display name of the list.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A patch model for updating reminders.
///
/// Only non-nil fields will be updated when applying this patch.
/// Pass `nil` for any field that should remain unchanged.
///
/// ## Example
/// ```swift
/// let patch = ReminderPatch(
///     title: "Buy organic groceries",
///     priority: 1
/// )
/// ```
public struct ReminderPatch: Codable, Sendable, Equatable {
    /// New title, or `nil` to keep existing.
    public let title: String?

    /// New due date/time in ISO 8601 format, or `nil` to keep existing.
    public let dueDate: String?

    /// New notes, or `nil` to keep existing.
    public let notes: String?

    /// New list ID to move the reminder, or `nil` to keep existing.
    public let listId: String?

    /// New priority level, or `nil` to keep existing.
    public let priority: Int?

    /// Creates a patch for updating a reminder.
    /// - Parameters:
    ///   - title: New title, or `nil` to keep existing.
    ///   - dueDate: New due date/time, or `nil` to keep existing.
    ///   - notes: New notes, or `nil` to keep existing.
    ///   - listId: New list ID, or `nil` to keep existing.
    ///   - priority: New priority, or `nil` to keep existing.
    public init(
        title: String? = nil,
        dueDate: String? = nil,
        notes: String? = nil,
        listId: String? = nil,
        priority: Int? = nil
    ) {
        self.title = title
        self.dueDate = dueDate
        self.notes = notes
        self.listId = listId
        self.priority = priority
    }
}
