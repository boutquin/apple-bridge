import Foundation
import MCP
import Core

/// Handlers for contacts MCP tools.
///
/// These handlers wire the `ContactsService` protocol to MCP tool calls,
/// handling argument parsing, response formatting, and error handling.
///
/// ## Tool Summary
/// | Tool | Operation | Required Args |
/// |------|-----------|---------------|
/// | `contacts_search` | Search contacts | `query` |
/// | `contacts_get` | Get contact | `id` |
/// | `contacts_me` | Get user's card | none |
/// | `contacts_open` | Open in app | `id` |
enum ContactsHandlers {

    // MARK: - Handler Implementations

    /// Handler for `contacts_search` - searches contacts by query.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `query` (required), optional `limit`.
    /// - Returns: JSON array of matching contacts.
    static func searchContacts(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let query = HandlerUtilities.extractString(from: arguments, key: "query") else {
            return HandlerUtilities.missingRequiredParameter("query")
        }

        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 10

        do {
            let contacts = try await services.contacts.search(query: query, limit: limit)
            return HandlerUtilities.successResult(contacts)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `contacts_get` - gets a single contact by ID.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: JSON object with the contact.
    static func getContact(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            let contact = try await services.contacts.get(id: id)
            return HandlerUtilities.successResult(contact)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `contacts_me` - gets the user's own contact card.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments (none required).
    /// - Returns: JSON object with the user's contact, or `null` if not configured.
    static func getMe(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        do {
            let contact = try await services.contacts.me()
            if let contact {
                return HandlerUtilities.successResult(contact)
            } else {
                return CallTool.Result(content: [.text("null")], isError: false)
            }
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `contacts_open` - opens a contact in the Contacts app.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: JSON object `{"opened": "<id>"}` on success.
    static func openContact(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            try await services.contacts.open(id: id)
            return CallTool.Result(
                content: [.text("{\"opened\": \"\(id)\"}")],
                isError: false
            )
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }
}
