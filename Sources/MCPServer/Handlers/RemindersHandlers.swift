import Foundation
import MCP
import Core

/// Handlers for reminders MCP tools.
///
/// These handlers wire the `RemindersService` protocol to MCP tool calls,
/// handling argument parsing, response formatting, and error handling.
///
/// ## Tool Summary
/// | Tool | Operation | Required Args |
/// |------|-----------|---------------|
/// | `reminders_get_lists` | Get all lists | none |
/// | `reminders_list` | List reminders | `listId` |
/// | `reminders_search` | Search reminders | `query` |
/// | `reminders_create` | Create reminder | `title` |
/// | `reminders_update` | Update reminder | `id` |
/// | `reminders_delete` | Delete reminder | `id` |
/// | `reminders_complete` | Complete reminder | `id` |
/// | `reminders_open` | Open in app | `id` |
enum RemindersHandlers {

    // MARK: - Handler Implementations

    /// Handler for `reminders_get_lists` - gets all reminder lists.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments (unused for this handler).
    /// - Returns: JSON array of reminder lists.
    static func getLists(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        do {
            let lists = try await services.reminders.getLists()
            return HandlerUtilities.successResult(lists)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `reminders_list` - lists reminders in a specific list.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `listId` (required), `limit`, `includeCompleted`, `cursor`.
    /// - Returns: Paginated JSON response with reminders.
    static func listReminders(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let listId = HandlerUtilities.extractString(from: arguments, key: "listId") else {
            return HandlerUtilities.missingRequiredParameter("listId")
        }

        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 10
        let includeCompleted = HandlerUtilities.extractBool(from: arguments, key: "includeCompleted") ?? false
        let cursor = HandlerUtilities.extractString(from: arguments, key: "cursor")

        do {
            let page = try await services.reminders.list(
                listId: listId,
                limit: limit,
                includeCompleted: includeCompleted,
                cursor: cursor
            )
            return HandlerUtilities.successResult(page)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `reminders_search` - searches reminders across all lists.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `query` (required), `limit`, `includeCompleted`, `cursor`.
    /// - Returns: Paginated JSON response with matching reminders.
    static func searchReminders(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let query = HandlerUtilities.extractString(from: arguments, key: "query") else {
            return HandlerUtilities.missingRequiredParameter("query")
        }

        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 10
        let includeCompleted = HandlerUtilities.extractBool(from: arguments, key: "includeCompleted") ?? false
        let cursor = HandlerUtilities.extractString(from: arguments, key: "cursor")

        do {
            let page = try await services.reminders.search(
                query: query,
                limit: limit,
                includeCompleted: includeCompleted,
                cursor: cursor
            )
            return HandlerUtilities.successResult(page)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `reminders_create` - creates a new reminder.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `title` (required), `dueDate`, `notes`, `listId`, `priority`.
    /// - Returns: JSON object with the created reminder's `id`.
    static func createReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let title = HandlerUtilities.extractString(from: arguments, key: "title") else {
            return HandlerUtilities.missingRequiredParameter("title")
        }

        let dueDate = HandlerUtilities.extractString(from: arguments, key: "dueDate")
        let notes = HandlerUtilities.extractString(from: arguments, key: "notes")
        let listId = HandlerUtilities.extractString(from: arguments, key: "listId")
        let priority = HandlerUtilities.extractInt(from: arguments, key: "priority")

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
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `reminders_update` - updates an existing reminder.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required), plus optional `title`, `dueDate`, `notes`, `listId`, `priority`.
    /// - Returns: JSON object with the updated reminder.
    static func updateReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        let patch = ReminderPatch(
            title: HandlerUtilities.extractString(from: arguments, key: "title"),
            dueDate: HandlerUtilities.extractString(from: arguments, key: "dueDate"),
            notes: HandlerUtilities.extractString(from: arguments, key: "notes"),
            listId: HandlerUtilities.extractString(from: arguments, key: "listId"),
            priority: HandlerUtilities.extractInt(from: arguments, key: "priority")
        )

        do {
            let reminder = try await services.reminders.update(id: id, patch: patch)
            return HandlerUtilities.successResult(reminder)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `reminders_delete` - deletes a reminder.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: JSON object `{"deleted": true}` on success.
    static func deleteReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            try await services.reminders.delete(id: id)
            return CallTool.Result(
                content: [.text("{\"deleted\": true}")],
                isError: false
            )
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `reminders_complete` - marks a reminder as completed.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: JSON object with the completed reminder.
    static func completeReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            let reminder = try await services.reminders.complete(id: id)
            return HandlerUtilities.successResult(reminder)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `reminders_open` - opens a reminder in the Reminders app.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: JSON object `{"opened": true}` on success.
    static func openReminder(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            try await services.reminders.open(id: id)
            return CallTool.Result(
                content: [.text("{\"opened\": true}")],
                isError: false
            )
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }
}
