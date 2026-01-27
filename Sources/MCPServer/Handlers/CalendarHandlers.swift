import Foundation
import MCP
import Core

/// Handlers for calendar MCP tools.
///
/// These handlers wire the `CalendarService` protocol to MCP tool calls,
/// handling argument parsing, response formatting, and error handling.
enum CalendarHandlers {

    // MARK: - Handler Implementations

    /// Handler for `calendar_list` - lists calendar events.
    static func listEvents(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        let limit = extractInt(from: arguments, key: "limit") ?? 10
        let from = extractString(from: arguments, key: "from")
        let to = extractString(from: arguments, key: "to")
        let cursor = extractString(from: arguments, key: "cursor")

        do {
            let page = try await services.calendar.listEvents(
                limit: limit,
                from: from,
                to: to,
                cursor: cursor
            )
            return successResult(page)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `calendar_search` - searches calendar events.
    static func searchEvents(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let query = extractString(from: arguments, key: "query") else {
            return missingRequiredParameter("query")
        }

        let limit = extractInt(from: arguments, key: "limit") ?? 10
        let from = extractString(from: arguments, key: "from")
        let to = extractString(from: arguments, key: "to")
        let cursor = extractString(from: arguments, key: "cursor")

        do {
            let page = try await services.calendar.searchEvents(
                query: query,
                limit: limit,
                from: from,
                to: to,
                cursor: cursor
            )
            return successResult(page)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `calendar_get` - gets a single event by ID.
    static func getEvent(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = extractString(from: arguments, key: "id") else {
            return missingRequiredParameter("id")
        }

        do {
            let event = try await services.calendar.getEvent(id: id)
            return successResult(event)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `calendar_create` - creates a new event.
    static func createEvent(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let title = extractString(from: arguments, key: "title") else {
            return missingRequiredParameter("title")
        }
        guard let startDate = extractString(from: arguments, key: "startDate") else {
            return missingRequiredParameter("startDate")
        }
        guard let endDate = extractString(from: arguments, key: "endDate") else {
            return missingRequiredParameter("endDate")
        }

        let calendarId = extractString(from: arguments, key: "calendarId")
        let location = extractString(from: arguments, key: "location")
        let notes = extractString(from: arguments, key: "notes")

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
            return errorResult(error)
        }
    }

    /// Handler for `calendar_update` - updates an existing event.
    static func updateEvent(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = extractString(from: arguments, key: "id") else {
            return missingRequiredParameter("id")
        }

        let patch = CalendarEventPatch(
            title: extractString(from: arguments, key: "title"),
            startDate: extractString(from: arguments, key: "startDate"),
            endDate: extractString(from: arguments, key: "endDate"),
            location: extractString(from: arguments, key: "location"),
            notes: extractString(from: arguments, key: "notes")
        )

        do {
            let event = try await services.calendar.updateEvent(id: id, patch: patch)
            return successResult(event)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `calendar_delete` - deletes an event.
    static func deleteEvent(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = extractString(from: arguments, key: "id") else {
            return missingRequiredParameter("id")
        }

        do {
            try await services.calendar.deleteEvent(id: id)
            return CallTool.Result(
                content: [.text("{\"deleted\": true}")],
                isError: false
            )
        } catch {
            return errorResult(error)
        }
    }

    // MARK: - Private Helpers

    /// Extracts a string value from arguments.
    private static func extractString(from arguments: [String: Value]?, key: String) -> String? {
        guard let arguments, let value = arguments[key] else { return nil }
        switch value {
        case .string(let str):
            return str
        default:
            return nil
        }
    }

    /// Extracts an integer value from arguments.
    private static func extractInt(from arguments: [String: Value]?, key: String) -> Int? {
        guard let arguments, let value = arguments[key] else { return nil }
        switch value {
        case .int(let num):
            return num
        case .double(let num):
            return Int(num)
        default:
            return nil
        }
    }

    /// Creates a success result from an Encodable value.
    private static func successResult<T: Encodable>(_ value: T) -> CallTool.Result {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            let json = String(data: data, encoding: .utf8) ?? "{}"
            return CallTool.Result(content: [.text(json)], isError: false)
        } catch {
            return CallTool.Result(
                content: [.text("Error encoding result: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    /// Creates an error result from an Error.
    private static func errorResult(_ error: Error) -> CallTool.Result {
        let message: String
        switch error {
        case let validationError as ValidationError:
            message = validationError.userMessage
        case let permissionError as PermissionError:
            message = permissionError.userMessage
        default:
            message = error.localizedDescription
        }
        return CallTool.Result(
            content: [.text("Error: \(message)")],
            isError: true
        )
    }

    /// Creates an error result for missing required parameter.
    private static func missingRequiredParameter(_ name: String) -> CallTool.Result {
        CallTool.Result(
            content: [.text("Missing required parameter: \(name)")],
            isError: true
        )
    }
}
