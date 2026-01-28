import Foundation
import MCP
import Core

/// Handlers for reminders MCP tools.
///
/// These handlers wire the `RemindersService` protocol to MCP tool calls,
/// handling argument parsing, response formatting, and error handling.
enum RemindersHandlers {

    // MARK: - Handler Implementations

    /// Handler for `reminders_get_lists` - gets all reminder lists.
    static func getLists(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        do {
            let lists = try await services.reminders.getLists()
            return successResult(lists)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `reminders_list` - lists reminders in a list.
    static func listReminders(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let listId = extractString(from: arguments, key: "listId") else {
            return missingRequiredParameter("listId")
        }

        let limit = extractInt(from: arguments, key: "limit") ?? 10
        let includeCompleted = extractBool(from: arguments, key: "includeCompleted") ?? false
        let cursor = extractString(from: arguments, key: "cursor")

        do {
            let page = try await services.reminders.list(
                listId: listId,
                limit: limit,
                includeCompleted: includeCompleted,
                cursor: cursor
            )
            return successResult(page)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `reminders_search` - searches reminders by query.
    static func searchReminders(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let query = extractString(from: arguments, key: "query") else {
            return missingRequiredParameter("query")
        }

        let limit = extractInt(from: arguments, key: "limit") ?? 10
        let includeCompleted = extractBool(from: arguments, key: "includeCompleted") ?? false
        let cursor = extractString(from: arguments, key: "cursor")

        do {
            let page = try await services.reminders.search(
                query: query,
                limit: limit,
                includeCompleted: includeCompleted,
                cursor: cursor
            )
            return successResult(page)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `reminders_create` - creates a new reminder.
    static func createReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let title = extractString(from: arguments, key: "title") else {
            return missingRequiredParameter("title")
        }

        let dueDate = extractString(from: arguments, key: "dueDate")
        let notes = extractString(from: arguments, key: "notes")
        let listId = extractString(from: arguments, key: "listId")
        let priority = extractInt(from: arguments, key: "priority")

        do {
            let id = try await services.reminders.create(
                title: title,
                dueDate: dueDate,
                notes: notes,
                listId: listId,
                priority: priority
            )
            return CallTool.Result(
                content: [.text("{\"id\": \"\(id)\"}")],
                isError: false
            )
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `reminders_update` - updates an existing reminder.
    static func updateReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = extractString(from: arguments, key: "id") else {
            return missingRequiredParameter("id")
        }

        let patch = ReminderPatch(
            title: extractString(from: arguments, key: "title"),
            dueDate: extractString(from: arguments, key: "dueDate"),
            notes: extractString(from: arguments, key: "notes"),
            listId: extractString(from: arguments, key: "listId"),
            priority: extractInt(from: arguments, key: "priority")
        )

        do {
            let reminder = try await services.reminders.update(id: id, patch: patch)
            return successResult(reminder)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `reminders_delete` - deletes a reminder.
    static func deleteReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = extractString(from: arguments, key: "id") else {
            return missingRequiredParameter("id")
        }

        do {
            try await services.reminders.delete(id: id)
            return CallTool.Result(
                content: [.text("{\"deleted\": true}")],
                isError: false
            )
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `reminders_complete` - marks a reminder as complete.
    static func completeReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = extractString(from: arguments, key: "id") else {
            return missingRequiredParameter("id")
        }

        do {
            let reminder = try await services.reminders.complete(id: id)
            return successResult(reminder)
        } catch {
            return errorResult(error)
        }
    }

    /// Handler for `reminders_open` - opens a reminder in the Reminders app.
    static func openReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = extractString(from: arguments, key: "id") else {
            return missingRequiredParameter("id")
        }

        do {
            try await services.reminders.open(id: id)
            return CallTool.Result(
                content: [.text("{\"opened\": true}")],
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

    /// Extracts a boolean value from arguments.
    private static func extractBool(from arguments: [String: Value]?, key: String) -> Bool? {
        guard let arguments, let value = arguments[key] else { return nil }
        switch value {
        case .bool(let b):
            return b
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
