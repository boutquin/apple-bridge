import Foundation

/// Calendar event model.
public struct CalendarEvent: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let startDate: String
    public let endDate: String
    public let calendarId: String
    public let location: String?
    public let notes: String?

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

/// Patch model for updating calendar events. Only non-nil fields are updated.
public struct CalendarEventPatch: Codable, Sendable {
    public let title: String?
    public let startDate: String?
    public let endDate: String?
    public let location: String?
    public let notes: String?

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
