import Foundation
import Core
import MCPServer

// MARK: - Calendar Factories

/// Creates a test calendar event with sensible defaults.
/// - Parameters:
///   - id: Unique identifier. Defaults to a new UUID.
///   - title: Event title. Defaults to "Test Event".
///   - startDate: Start date in ISO 8601 format. Defaults to "2026-01-27T10:00:00Z".
///   - endDate: End date in ISO 8601 format. Defaults to "2026-01-27T11:00:00Z".
///   - calendarId: Calendar identifier. Defaults to "cal-1".
///   - location: Event location. Defaults to nil.
///   - notes: Event notes. Defaults to nil.
/// - Returns: A configured `CalendarEvent` instance.
public func makeTestEvent(
    id: String = UUID().uuidString,
    title: String = "Test Event",
    startDate: String = "2026-01-27T10:00:00Z",
    endDate: String = "2026-01-27T11:00:00Z",
    calendarId: String = "cal-1",
    location: String? = nil,
    notes: String? = nil
) -> CalendarEvent {
    CalendarEvent(
        id: id,
        title: title,
        startDate: startDate,
        endDate: endDate,
        calendarId: calendarId,
        location: location,
        notes: notes
    )
}

// MARK: - Reminder Factories

/// Creates a test reminder with sensible defaults.
/// - Parameters:
///   - id: Unique identifier. Defaults to a new UUID.
///   - title: Reminder title. Defaults to "Test Reminder".
///   - dueDate: Due date in ISO 8601 format. Defaults to nil.
///   - notes: Additional notes. Defaults to nil.
///   - isCompleted: Completion status. Defaults to false.
///   - listId: List identifier. Defaults to "list-1".
///   - priority: Priority level. Defaults to nil.
/// - Returns: A configured `Reminder` instance.
public func makeTestReminder(
    id: String = UUID().uuidString,
    title: String = "Test Reminder",
    dueDate: String? = nil,
    notes: String? = nil,
    isCompleted: Bool = false,
    listId: String = "list-1",
    priority: Int? = nil
) -> Reminder {
    Reminder(
        id: id,
        title: title,
        dueDate: dueDate,
        notes: notes,
        isCompleted: isCompleted,
        listId: listId,
        priority: priority
    )
}

/// Creates a test reminder list with sensible defaults.
/// - Parameters:
///   - id: Unique identifier. Defaults to a new UUID.
///   - name: List name. Defaults to "Test List".
/// - Returns: A configured `ReminderList` instance.
public func makeTestReminderList(
    id: String = UUID().uuidString,
    name: String = "Test List"
) -> ReminderList {
    ReminderList(id: id, name: name)
}

// MARK: - Contact Factories

/// Creates a test contact with sensible defaults.
/// - Parameters:
///   - id: Unique identifier. Defaults to a new UUID.
///   - displayName: Full name. Defaults to "Test Contact".
///   - email: Email address. Defaults to "test@example.com".
///   - phone: Phone number. Defaults to nil.
/// - Returns: A configured `Contact` instance.
public func makeTestContact(
    id: String = UUID().uuidString,
    displayName: String = "Test Contact",
    email: String? = "test@example.com",
    phone: String? = nil
) -> Contact {
    Contact(
        id: id,
        displayName: displayName,
        email: email,
        phone: phone
    )
}

// MARK: - Note Factories

/// Creates a test note with sensible defaults.
/// - Parameters:
///   - id: Unique identifier. Defaults to a new UUID.
///   - title: Note title. Defaults to "Test Note".
///   - body: Note body content. Defaults to nil.
///   - folderId: Folder identifier. Defaults to nil.
///   - modifiedAt: Modification timestamp in ISO 8601 format. Defaults to "2026-01-27T10:00:00Z".
/// - Returns: A configured `Note` instance.
public func makeTestNote(
    id: String = UUID().uuidString,
    title: String? = "Test Note",
    body: String? = nil,
    folderId: String? = nil,
    modifiedAt: String = "2026-01-27T10:00:00Z"
) -> Note {
    Note(
        id: id,
        title: title,
        body: body,
        folderId: folderId,
        modifiedAt: modifiedAt
    )
}

// MARK: - Message Factories

/// Creates a test message with sensible defaults.
/// - Parameters:
///   - id: Unique identifier. Defaults to a new UUID.
///   - chatId: Chat identifier. Defaults to "chat-1".
///   - sender: Sender phone/email. Defaults to "+1234567890".
///   - date: Send timestamp in ISO 8601 format. Defaults to "2026-01-27T10:00:00Z".
///   - body: Message content. Defaults to "Test message".
///   - isUnread: Read status. Defaults to false.
/// - Returns: A configured `Message` instance.
public func makeTestMessage(
    id: String = UUID().uuidString,
    chatId: String = "chat-1",
    sender: String = "+1234567890",
    date: String = "2026-01-27T10:00:00Z",
    body: String? = "Test message",
    isUnread: Bool = false
) -> Message {
    Message(
        id: id,
        chatId: chatId,
        sender: sender,
        date: date,
        body: body,
        isUnread: isUnread
    )
}

// MARK: - Email Factories

/// Creates a test email with sensible defaults.
/// - Parameters:
///   - id: Unique identifier. Defaults to a new UUID.
///   - subject: Email subject. Defaults to "Test Subject".
///   - from: Sender address. Defaults to "sender@example.com".
///   - to: Recipient addresses. Defaults to ["recipient@example.com"].
///   - date: Send timestamp in ISO 8601 format. Defaults to "2026-01-27T10:00:00Z".
///   - body: Email body content. Defaults to nil.
///   - mailbox: Mailbox name. Defaults to "INBOX".
///   - isUnread: Read status. Defaults to false.
/// - Returns: A configured `Email` instance.
public func makeTestEmail(
    id: String = UUID().uuidString,
    subject: String = "Test Subject",
    from: String = "sender@example.com",
    to: [String] = ["recipient@example.com"],
    date: String = "2026-01-27T10:00:00Z",
    body: String? = nil,
    mailbox: String? = "INBOX",
    isUnread: Bool = false
) -> Email {
    Email(
        id: id,
        subject: subject,
        from: from,
        to: to,
        date: date,
        body: body,
        mailbox: mailbox,
        isUnread: isUnread
    )
}

// MARK: - Location Factories

/// Creates a test location with sensible defaults.
/// - Parameters:
///   - name: Location name. Defaults to "Test Location".
///   - address: Street address. Defaults to "123 Test St".
///   - latitude: Latitude coordinate. Defaults to 37.3349 (Apple Park).
///   - longitude: Longitude coordinate. Defaults to -122.0090 (Apple Park).
/// - Returns: A configured `Location` instance.
public func makeTestLocation(
    name: String = "Test Location",
    address: String? = "123 Test St",
    latitude: Double? = 37.3349,
    longitude: Double? = -122.0090
) -> Location {
    Location(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude
    )
}

// MARK: - Cursor Factory

/// Creates a test cursor with sensible defaults.
/// - Parameters:
///   - lastId: Last item ID. Defaults to "item-1".
///   - ts: Unix timestamp. Defaults to 1706400000.
/// - Returns: A configured `Cursor` instance.
public func makeTestCursor(
    lastId: String = "item-1",
    ts: Int = 1706400000
) -> Cursor {
    Cursor(lastId: lastId, ts: ts)
}

// MARK: - Page Factory

/// Creates a test page with sensible defaults.
/// - Parameters:
///   - items: Page items.
///   - nextCursor: Cursor for next page. Defaults to nil.
///   - hasMore: Whether more pages exist. Defaults to false.
/// - Returns: A configured `Page` instance.
public func makeTestPage<T: Codable & Sendable>(
    items: [T],
    nextCursor: String? = nil,
    hasMore: Bool = false
) -> Page<T> {
    Page(items: items, nextCursor: nextCursor, hasMore: hasMore)
}

// MARK: - Services Factory

/// Container for all mock services, used for testing service integration.
///
/// ## Example
/// ```swift
/// let services = makeTestServices()
/// await services.calendar.setStubEvents([makeTestEvent()])
/// let events = try await services.calendar.listEvents(limit: 10, from: nil, to: nil, cursor: nil)
/// ```
public struct TestServices: AppleServicesProtocol, Sendable {
    /// Mock calendar service.
    public let calendar: any CalendarService
    /// Mock reminders service.
    public let reminders: any RemindersService
    /// Mock contacts service.
    public let contacts: any ContactsService
    /// Mock notes service.
    public let notes: any NotesService
    /// Mock messages service.
    public let messages: any MessagesService
    /// Mock mail service.
    public let mail: any MailService
    /// Mock maps service.
    public let maps: any MapsService

    // Typed accessors for test setup convenience
    public var mockCalendar: MockCalendarService { calendar as! MockCalendarService }
    public var mockReminders: MockRemindersService { reminders as! MockRemindersService }
    public var mockContacts: MockContactsService { contacts as! MockContactsService }
    public var mockNotes: MockNotesService { notes as! MockNotesService }
    public var mockMessages: MockMessagesService { messages as! MockMessagesService }
    public var mockMail: MockMailService { mail as! MockMailService }
    public var mockMaps: MockMapsService { maps as! MockMapsService }

    /// Creates a new test services container with fresh mocks.
    public init() {
        self.calendar = MockCalendarService()
        self.reminders = MockRemindersService()
        self.contacts = MockContactsService()
        self.notes = MockNotesService()
        self.messages = MockMessagesService()
        self.mail = MockMailService()
        self.maps = MockMapsService()
    }
}

/// Creates a container with all mock services for integration testing.
/// - Returns: A `TestServices` instance with fresh mock implementations.
public func makeTestServices() -> TestServices {
    TestServices()
}

// MARK: - MCP Infrastructure Factories

/// Creates a ToolRegistry with mock services for testing.
///
/// ## Example
/// ```swift
/// let registry = makeTestRegistry()
/// let definitions = await registry.definitions
/// let result = await registry.callTool(name: "calendar_list", arguments: nil)
/// ```
/// - Returns: A `ToolRegistry` instance configured with mock services.
public func makeTestRegistry() -> ToolRegistry {
    ToolRegistry.create(services: makeTestServices())
}

/// Creates a ToolDispatcher with mock services for testing.
///
/// ## Example
/// ```swift
/// let dispatcher = makeTestDispatcher()
/// let result = await dispatcher.dispatch(name: "calendar_list", arguments: nil)
/// ```
/// - Parameter timeout: The timeout duration for tool calls. Defaults to 30 seconds.
/// - Returns: A `ToolDispatcher` instance configured with mock services.
public func makeTestDispatcher(timeout: Duration = .seconds(30)) -> ToolDispatcher {
    ToolDispatcher(registry: makeTestRegistry(), timeout: timeout)
}
