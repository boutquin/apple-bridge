import Foundation
import MCP
import Core

/// Registry of all MCP tools available in apple-bridge.
///
/// The ToolRegistry holds the definitions of all 37 tools and their handlers.
/// At Phase 4, all handlers return NOT_IMPLEMENTED. Real handlers are wired in Phases 5-12.
///
/// ## Usage
/// ```swift
/// let services = makeTestServices()
/// let registry = ToolRegistry.create(services: services)
/// let tools = await registry.definitions
/// let result = await registry.callTool(name: "calendar_list", arguments: nil)
/// ```
public actor ToolRegistry {

    // MARK: - Types

    /// A handler that processes a tool call and returns a result.
    public typealias ToolHandler = @Sendable ([String: Value]?) async -> CallTool.Result

    /// An entry in the tool registry containing the definition and handler.
    private struct ToolEntry: Sendable {
        let definition: Tool
        let handler: ToolHandler
    }

    // MARK: - Properties

    /// All registered tools, keyed by name.
    private var tools: [String: ToolEntry]

    /// The services container used by handlers.
    private let services: any AppleServicesProtocol

    // MARK: - Initialization

    /// Creates a new tool registry with all 37 tools registered.
    /// - Parameter services: The services container to use for tool handlers.
    /// - Note: Uses a private initializer; use `create(services:)` factory method.
    private init(services: any AppleServicesProtocol, tools: [String: ToolEntry]) {
        self.services = services
        self.tools = tools
    }

    /// Creates a new tool registry with all 37 tools registered.
    /// - Parameter services: The services container to use for tool handlers.
    /// - Returns: A configured `ToolRegistry` instance.
    public static func create(services: any AppleServicesProtocol) -> ToolRegistry {
        var tools: [String: ToolEntry] = [:]

        // Calendar tools (6) - Phase 5: Real handlers wired
        registerCalendarTools(into: &tools, services: services)

        // Reminders tools (8) - Phase 6: Real handlers wired
        registerRemindersTools(into: &tools, services: services)

        // Contacts tools (4) - Phase 7: Real handlers wired
        registerContactsTools(into: &tools, services: services)

        // Notes tools (4) - Phase 9: Real handlers wired
        registerNotesTools(into: &tools, services: services)

        // Messages tools (5) - Phase 10: Real handlers wired
        registerMessagesTools(into: &tools, services: services)

        // Mail tools (4)
        registerMailTools(into: &tools)

        // Maps tools (6)
        registerMapsTools(into: &tools)

        return ToolRegistry(services: services, tools: tools)
    }

    // MARK: - Public API

    /// All tool definitions in the registry.
    public var definitions: [Tool] {
        tools.values.map(\.definition)
    }

    /// Calls a tool by name with the given arguments.
    /// - Parameters:
    ///   - name: The tool name.
    ///   - arguments: The tool arguments.
    /// - Returns: The tool result.
    public func callTool(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        guard let entry = tools[name] else {
            return CallTool.Result(
                content: [.text("UNKNOWN_TOOL: '\(name)' is not a registered tool")],
                isError: true
            )
        }

        return await entry.handler(arguments)
    }

    /// Updates the handler for an existing tool.
    ///
    /// This method will be used in Phases 5-12 to wire real handlers.
    ///
    /// - Parameters:
    ///   - name: The name of the tool to update.
    ///   - handler: The new handler to use for this tool.
    /// - Note: If the tool doesn't exist, this method does nothing.
    public func setHandler(for name: String, handler: @escaping ToolHandler) {
        guard let entry = tools[name] else { return }
        tools[name] = ToolEntry(definition: entry.definition, handler: handler)
    }

    // MARK: - Static Registration Helpers

    /// Registers a tool with a stub handler that returns NOT_IMPLEMENTED.
    private static func register(
        into tools: inout [String: ToolEntry],
        name: String,
        description: String,
        inputSchema: Value
    ) {
        let definition = Tool(
            name: name,
            description: description,
            inputSchema: inputSchema
        )

        let handler: ToolHandler = { _ in
            CallTool.Result(
                content: [.text("NOT_IMPLEMENTED: '\(name)' handler not yet implemented")],
                isError: true
            )
        }

        tools[name] = ToolEntry(definition: definition, handler: handler)
    }

    /// Registers a tool with a real handler implementation.
    private static func registerWithHandler(
        into tools: inout [String: ToolEntry],
        name: String,
        description: String,
        inputSchema: Value,
        handler: @escaping ToolHandler
    ) {
        let definition = Tool(
            name: name,
            description: description,
            inputSchema: inputSchema
        )

        tools[name] = ToolEntry(definition: definition, handler: handler)
    }

    // MARK: - Calendar Tools (6)

    /// Registers calendar tools with real handlers (Phase 5).
    private static func registerCalendarTools(into tools: inout [String: ToolEntry], services: any AppleServicesProtocol) {
        registerWithHandler(
            into: &tools,
            name: "calendar_list",
            description: "List calendar events within a date range",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "limit": .object(["type": "integer", "description": "Maximum number of events to return"]),
                    "from": .object(["type": "string", "description": "Start date in ISO 8601 format"]),
                    "to": .object(["type": "string", "description": "End date in ISO 8601 format"]),
                    "cursor": .object(["type": "string", "description": "Pagination cursor"])
                ])
            ]),
            handler: { args in await CalendarHandlers.listEvents(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "calendar_search",
            description: "Search calendar events by query",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object(["type": "string", "description": "Search query"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of events to return"]),
                    "from": .object(["type": "string", "description": "Start date in ISO 8601 format"]),
                    "to": .object(["type": "string", "description": "End date in ISO 8601 format"]),
                    "cursor": .object(["type": "string", "description": "Pagination cursor"])
                ]),
                "required": .array([.string("query")])
            ]),
            handler: { args in await CalendarHandlers.searchEvents(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "calendar_get",
            description: "Get a calendar event by ID",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Event ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await CalendarHandlers.getEvent(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "calendar_create",
            description: "Create a new calendar event",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "title": .object(["type": "string", "description": "Event title"]),
                    "startDate": .object(["type": "string", "description": "Start date in ISO 8601 format"]),
                    "endDate": .object(["type": "string", "description": "End date in ISO 8601 format"]),
                    "calendarId": .object(["type": "string", "description": "Calendar ID"]),
                    "location": .object(["type": "string", "description": "Event location"]),
                    "notes": .object(["type": "string", "description": "Event notes"])
                ]),
                "required": .array([.string("title"), .string("startDate"), .string("endDate")])
            ]),
            handler: { args in await CalendarHandlers.createEvent(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "calendar_update",
            description: "Update an existing calendar event",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Event ID"]),
                    "title": .object(["type": "string", "description": "New event title"]),
                    "startDate": .object(["type": "string", "description": "New start date in ISO 8601 format"]),
                    "endDate": .object(["type": "string", "description": "New end date in ISO 8601 format"]),
                    "location": .object(["type": "string", "description": "New event location"]),
                    "notes": .object(["type": "string", "description": "New event notes"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await CalendarHandlers.updateEvent(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "calendar_delete",
            description: "Delete a calendar event",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Event ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await CalendarHandlers.deleteEvent(services: services, arguments: args) }
        )
    }

    // MARK: - Reminders Tools (8)

    /// Registers reminders tools with real handlers (Phase 6).
    private static func registerRemindersTools(into tools: inout [String: ToolEntry], services: any AppleServicesProtocol) {
        registerWithHandler(
            into: &tools,
            name: "reminders_get_lists",
            description: "Get all reminder lists",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:])
            ]),
            handler: { args in await RemindersHandlers.getLists(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "reminders_list",
            description: "List reminders in a list",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "listId": .object(["type": "string", "description": "List ID"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of reminders to return"]),
                    "includeCompleted": .object(["type": "boolean", "description": "Whether to include completed reminders"]),
                    "cursor": .object(["type": "string", "description": "Pagination cursor"])
                ]),
                "required": .array([.string("listId")])
            ]),
            handler: { args in await RemindersHandlers.listReminders(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "reminders_search",
            description: "Search reminders by query",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object(["type": "string", "description": "Search query"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of reminders to return"]),
                    "includeCompleted": .object(["type": "boolean", "description": "Whether to include completed reminders"]),
                    "cursor": .object(["type": "string", "description": "Pagination cursor"])
                ]),
                "required": .array([.string("query")])
            ]),
            handler: { args in await RemindersHandlers.searchReminders(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "reminders_create",
            description: "Create a new reminder",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "title": .object(["type": "string", "description": "Reminder title"]),
                    "dueDate": .object(["type": "string", "description": "Due date in ISO 8601 format"]),
                    "notes": .object(["type": "string", "description": "Reminder notes"]),
                    "listId": .object(["type": "string", "description": "List ID"]),
                    "priority": .object(["type": "integer", "description": "Priority (1-9)"])
                ]),
                "required": .array([.string("title")])
            ]),
            handler: { args in await RemindersHandlers.createReminder(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "reminders_update",
            description: "Update an existing reminder",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Reminder ID"]),
                    "title": .object(["type": "string", "description": "New reminder title"]),
                    "dueDate": .object(["type": "string", "description": "New due date in ISO 8601 format"]),
                    "notes": .object(["type": "string", "description": "New reminder notes"]),
                    "listId": .object(["type": "string", "description": "New list ID"]),
                    "priority": .object(["type": "integer", "description": "New priority (1-9)"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await RemindersHandlers.updateReminder(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "reminders_delete",
            description: "Delete a reminder",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Reminder ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await RemindersHandlers.deleteReminder(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "reminders_complete",
            description: "Mark a reminder as complete",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Reminder ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await RemindersHandlers.completeReminder(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "reminders_open",
            description: "Open a reminder in the Reminders app",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Reminder ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await RemindersHandlers.openReminder(services: services, arguments: args) }
        )
    }

    // MARK: - Contacts Tools (4)

    /// Registers contacts tools with real handlers (Phase 7).
    private static func registerContactsTools(into tools: inout [String: ToolEntry], services: any AppleServicesProtocol) {
        registerWithHandler(
            into: &tools,
            name: "contacts_search",
            description: "Search contacts by query",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object(["type": "string", "description": "Search query"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of contacts to return"])
                ]),
                "required": .array([.string("query")])
            ]),
            handler: { args in await ContactsHandlers.searchContacts(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "contacts_get",
            description: "Get a contact by ID",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Contact ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await ContactsHandlers.getContact(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "contacts_me",
            description: "Get the current user's contact card",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:])
            ]),
            handler: { args in await ContactsHandlers.getMe(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "contacts_open",
            description: "Open a contact in the Contacts app",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Contact ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await ContactsHandlers.openContact(services: services, arguments: args) }
        )
    }

    // MARK: - Notes Tools (4)

    /// Registers notes tools with real handlers (Phase 9).
    private static func registerNotesTools(into tools: inout [String: ToolEntry], services: any AppleServicesProtocol) {
        registerWithHandler(
            into: &tools,
            name: "notes_search",
            description: "Search notes by query",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object(["type": "string", "description": "Search query"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of notes to return"]),
                    "includeBody": .object(["type": "boolean", "description": "Whether to include note bodies"])
                ]),
                "required": .array([.string("query")])
            ]),
            handler: { args in await NotesHandlers.searchNotes(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "notes_get",
            description: "Get a note by ID",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Note ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await NotesHandlers.getNote(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "notes_create",
            description: "Create a new note",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "title": .object(["type": "string", "description": "Note title"]),
                    "body": .object(["type": "string", "description": "Note body"]),
                    "folderId": .object(["type": "string", "description": "Folder ID"])
                ]),
                "required": .array([.string("title")])
            ]),
            handler: { args in await NotesHandlers.createNote(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "notes_open",
            description: "Open a note in the Notes app",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Note ID"])
                ]),
                "required": .array([.string("id")])
            ]),
            handler: { args in await NotesHandlers.openNote(services: services, arguments: args) }
        )
    }

    // MARK: - Messages Tools (5)

    /// Registers messages tools with real handlers (Phase 10).
    private static func registerMessagesTools(into tools: inout [String: ToolEntry], services: any AppleServicesProtocol) {
        registerWithHandler(
            into: &tools,
            name: "messages_list_chats",
            description: "List message chats",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "limit": .object(["type": "integer", "description": "Maximum number of chats to return"])
                ])
            ]),
            handler: { args in await MessagesHandlers.listChats(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "messages_read",
            description: "Read messages from a chat",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "chatId": .object(["type": "string", "description": "Chat ID"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of messages to return"]),
                    "cursor": .object(["type": "string", "description": "Pagination cursor"])
                ]),
                "required": .array([.string("chatId")])
            ]),
            handler: { args in await MessagesHandlers.readMessages(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "messages_unread",
            description: "Get unread messages",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "limit": .object(["type": "integer", "description": "Maximum number of messages to return"])
                ])
            ]),
            handler: { args in await MessagesHandlers.unreadMessages(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "messages_send",
            description: "Send a message",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "to": .object(["type": "string", "description": "Recipient phone number or email"]),
                    "body": .object(["type": "string", "description": "Message body"])
                ]),
                "required": .array([.string("to"), .string("body")])
            ]),
            handler: { args in await MessagesHandlers.sendMessage(services: services, arguments: args) }
        )

        registerWithHandler(
            into: &tools,
            name: "messages_schedule",
            description: "Schedule a message to be sent later",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "to": .object(["type": "string", "description": "Recipient phone number or email"]),
                    "body": .object(["type": "string", "description": "Message body"]),
                    "scheduledAt": .object(["type": "string", "description": "Send time in ISO 8601 format"])
                ]),
                "required": .array([.string("to"), .string("body"), .string("scheduledAt")])
            ]),
            handler: { args in await MessagesHandlers.scheduleMessage(services: services, arguments: args) }
        )
    }

    // MARK: - Mail Tools (4)

    private static func registerMailTools(into tools: inout [String: ToolEntry]) {
        register(
            into: &tools,
            name: "mail_search",
            description: "Search emails by query",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object(["type": "string", "description": "Search query"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of emails to return"]),
                    "includeBody": .object(["type": "boolean", "description": "Whether to include email bodies"]),
                    "cursor": .object(["type": "string", "description": "Pagination cursor"])
                ]),
                "required": .array([.string("query")])
            ])
        )

        register(
            into: &tools,
            name: "mail_unread",
            description: "Get unread emails",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "limit": .object(["type": "integer", "description": "Maximum number of emails to return"]),
                    "includeBody": .object(["type": "boolean", "description": "Whether to include email bodies"])
                ])
            ])
        )

        register(
            into: &tools,
            name: "mail_send",
            description: "Send an email",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "to": .object(["type": "array", "items": .object(["type": "string"]), "description": "Recipient email addresses"]),
                    "subject": .object(["type": "string", "description": "Email subject"]),
                    "body": .object(["type": "string", "description": "Email body"]),
                    "cc": .object(["type": "array", "items": .object(["type": "string"]), "description": "CC email addresses"]),
                    "bcc": .object(["type": "array", "items": .object(["type": "string"]), "description": "BCC email addresses"])
                ]),
                "required": .array([.string("to"), .string("subject"), .string("body")])
            ])
        )

        register(
            into: &tools,
            name: "mail_compose",
            description: "Open a new email compose window",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "to": .object(["type": "array", "items": .object(["type": "string"]), "description": "Recipient email addresses"]),
                    "subject": .object(["type": "string", "description": "Email subject"]),
                    "body": .object(["type": "string", "description": "Email body"])
                ])
            ])
        )
    }

    // MARK: - Maps Tools (6)

    private static func registerMapsTools(into tools: inout [String: ToolEntry]) {
        register(
            into: &tools,
            name: "maps_search",
            description: "Search for locations",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object(["type": "string", "description": "Search query"]),
                    "near": .object(["type": "string", "description": "Location to search near"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of results to return"])
                ]),
                "required": .array([.string("query")])
            ])
        )

        register(
            into: &tools,
            name: "maps_directions",
            description: "Get directions between two locations",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "from": .object(["type": "string", "description": "Starting location"]),
                    "to": .object(["type": "string", "description": "Destination location"]),
                    "mode": .object(["type": "string", "enum": .array([.string("driving"), .string("walking"), .string("transit")]), "description": "Travel mode"])
                ]),
                "required": .array([.string("from"), .string("to")])
            ])
        )

        register(
            into: &tools,
            name: "maps_open",
            description: "Open a location in the Maps app",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object(["type": "string", "description": "Location to open"])
                ]),
                "required": .array([.string("query")])
            ])
        )

        register(
            into: &tools,
            name: "maps_list_guides",
            description: "List saved guides",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:])
            ])
        )

        register(
            into: &tools,
            name: "maps_open_guide",
            description: "Open a guide in the Maps app",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "name": .object(["type": "string", "description": "Guide name"])
                ]),
                "required": .array([.string("name")])
            ])
        )

        register(
            into: &tools,
            name: "maps_nearby",
            description: "Find nearby places by category",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "category": .object(["type": "string", "description": "Category to search for (e.g., coffee, restaurant)"]),
                    "near": .object(["type": "string", "description": "Location to search near"]),
                    "limit": .object(["type": "integer", "description": "Maximum number of results to return"])
                ]),
                "required": .array([.string("category")])
            ])
        )
    }
}
