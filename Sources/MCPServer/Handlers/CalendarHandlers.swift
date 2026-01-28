import Foundation
import MCP
import Core

/// Handlers for calendar MCP tools.
///
/// These handlers wire the `CalendarService` protocol to MCP tool calls,
/// handling argument parsing, response formatting, and error handling.
///
/// ## Tool Summary
/// | Tool | Operation | Required Args |
/// |------|-----------|---------------|
/// | `calendar_list` | List events | none |
/// | `calendar_search` | Search events | `query` |
/// | `calendar_get` | Get event | `id` |
/// | `calendar_create` | Create event | `title`, `startDate`, `endDate` |
/// | `calendar_update` | Update event | `id` |
/// | `calendar_delete` | Delete event | `id` |
enum CalendarHandlers {

    // MARK: - Handler Implementations

    /// Handler for `calendar_list` - lists calendar events.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing optional `limit`, `from`, `to`, `cursor`.
    /// - Returns: Paginated JSON response with events.
    static func listEvents(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 10
        let from = HandlerUtilities.extractString(from: arguments, key: "from")
        let to = HandlerUtilities.extractString(from: arguments, key: "to")
        let cursor = HandlerUtilities.extractString(from: arguments, key: "cursor")

        do {
            let page = try await services.calendar.listEvents(
                limit: limit,
                from: from,
                to: to,
                cursor: cursor
            )
            return HandlerUtilities.successResult(page)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `calendar_search` - searches calendar events.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `query` (required), `limit`, `from`, `to`, `cursor`.
    /// - Returns: Paginated JSON response with matching events.
    static func searchEvents(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let query = HandlerUtilities.extractString(from: arguments, key: "query") else {
            return HandlerUtilities.missingRequiredParameter("query")
        }

        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 10
        let from = HandlerUtilities.extractString(from: arguments, key: "from")
        let to = HandlerUtilities.extractString(from: arguments, key: "to")
        let cursor = HandlerUtilities.extractString(from: arguments, key: "cursor")

        do {
            let page = try await services.calendar.searchEvents(
                query: query,
                limit: limit,
                from: from,
                to: to,
                cursor: cursor
            )
            return HandlerUtilities.successResult(page)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `calendar_get` - gets a single event by ID.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: JSON object with the event.
    static func getEvent(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            let event = try await services.calendar.getEvent(id: id)
            return HandlerUtilities.successResult(event)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `calendar_create` - creates a new calendar event.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `title`, `startDate`, `endDate` (required), plus optional `calendarId`, `location`, `notes`.
    /// - Returns: JSON object with the created event's `id`.
    static func createEvent(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let title = HandlerUtilities.extractString(from: arguments, key: "title") else {
            return HandlerUtilities.missingRequiredParameter("title")
        }
        guard let startDate = HandlerUtilities.extractString(from: arguments, key: "startDate") else {
            return HandlerUtilities.missingRequiredParameter("startDate")
        }
        guard let endDate = HandlerUtilities.extractString(from: arguments, key: "endDate") else {
            return HandlerUtilities.missingRequiredParameter("endDate")
        }

        let calendarId = HandlerUtilities.extractString(from: arguments, key: "calendarId")
        let location = HandlerUtilities.extractString(from: arguments, key: "location")
        let notes = HandlerUtilities.extractString(from: arguments, key: "notes")

        do {
            let id = try await services.calendar.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendarId: calendarId,
                location: location,
                notes: notes
            )
            return CallTool.Result(
                content: [.text("{\"id\": \"\(id)\"}")],
                isError: false
            )
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `calendar_update` - updates an existing calendar event.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required), plus optional `title`, `startDate`, `endDate`, `location`, `notes`.
    /// - Returns: JSON object with the updated event.
    static func updateEvent(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        let patch = CalendarEventPatch(
            title: HandlerUtilities.extractString(from: arguments, key: "title"),
            startDate: HandlerUtilities.extractString(from: arguments, key: "startDate"),
            endDate: HandlerUtilities.extractString(from: arguments, key: "endDate"),
            location: HandlerUtilities.extractString(from: arguments, key: "location"),
            notes: HandlerUtilities.extractString(from: arguments, key: "notes")
        )

        do {
            let event = try await services.calendar.updateEvent(id: id, patch: patch)
            return HandlerUtilities.successResult(event)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `calendar_delete` - deletes a calendar event.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: JSON object `{"deleted": true}` on success.
    static func deleteEvent(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            try await services.calendar.deleteEvent(id: id)
            return CallTool.Result(
                content: [.text("{\"deleted\": true}")],
                isError: false
            )
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }
}
