import Foundation
import Core

/// Protocol defining the services container interface.
///
/// This protocol allows ToolRegistry to accept either the production `AppleServices`
/// container or the test `TestServices` container for dependency injection.
public protocol AppleServicesProtocol: Sendable {
    /// The calendar service.
    var calendar: any CalendarService { get }
    /// The reminders service.
    var reminders: any RemindersService { get }
    /// The contacts service.
    var contacts: any ContactsService { get }
    /// The notes service.
    var notes: any NotesService { get }
    /// The messages service.
    var messages: any MessagesService { get }
    /// The mail service.
    var mail: any MailService { get }
    /// The maps service.
    var maps: any MapsService { get }
}

/// Production container for all Apple service implementations.
///
/// This container holds the real service implementations that interact with
/// macOS system frameworks (EventKit, Contacts, SQLite databases, AppleScript, etc.).
///
/// ## Usage
/// ```swift
/// let services = AppleServices(
///     calendar: EventKitCalendarService(),
///     reminders: EventKitRemindersService(),
///     // ... other services
/// )
/// let registry = await ToolRegistry(services: services)
/// ```
public struct AppleServices: AppleServicesProtocol, Sendable {
    public let calendar: any CalendarService
    public let reminders: any RemindersService
    public let contacts: any ContactsService
    public let notes: any NotesService
    public let messages: any MessagesService
    public let mail: any MailService
    public let maps: any MapsService

    public init(
        calendar: any CalendarService,
        reminders: any RemindersService,
        contacts: any ContactsService,
        notes: any NotesService,
        messages: any MessagesService,
        mail: any MailService,
        maps: any MapsService
    ) {
        self.calendar = calendar
        self.reminders = reminders
        self.contacts = contacts
        self.notes = notes
        self.messages = messages
        self.mail = mail
        self.maps = maps
    }
}
