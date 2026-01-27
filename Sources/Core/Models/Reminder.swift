import Foundation

/// Reminder model.
public struct Reminder: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let dueDate: String?
    public let notes: String?
    public let isCompleted: Bool
    public let listId: String
    public let priority: Int?

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

/// Reminder list model.
public struct ReminderList: Codable, Sendable, Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Patch model for updating reminders. Only non-nil fields are updated.
public struct ReminderPatch: Codable, Sendable {
    public let title: String?
    public let dueDate: String?
    public let notes: String?
    public let listId: String?
    public let priority: Int?

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
