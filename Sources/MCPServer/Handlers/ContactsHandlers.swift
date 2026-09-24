import Foundation
import MCP
import AppleBridgeCore

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
/// | `contacts_create` | Create a contact | one of `givenName` / `familyName` / `displayName` |
/// | `contacts_update` | Update a contact | `id` |
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
                return CallTool.Result(content: [.plain("null")], isError: false)
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
                content: [.plain("{\"opened\": \"\(id)\"}")],
                isError: false
            )
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - Write Handlers

    /// Handler for `contacts_create` — creates a new contact.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments. At least one of `givenName`, `familyName`,
    ///     or `displayName` is required; `organization`, `jobTitle`, `note`,
    ///     `email`, `phone`, `emails`, `phones`, `urls` are optional.
    /// - Returns: JSON object with the created contact, including its new `id`.
    static func createContact(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        let givenName = HandlerUtilities.extractString(from: arguments, key: "givenName")
        let familyName = HandlerUtilities.extractString(from: arguments, key: "familyName")
        let displayName = HandlerUtilities.extractString(from: arguments, key: "displayName")

        guard [givenName, familyName, displayName].contains(where: { $0?.isEmpty == false }) else {
            return HandlerUtilities.missingRequiredParameter("givenName, familyName, or displayName")
        }

        let draft: Contact
        do {
            draft = try Self.contact(from: arguments, id: "", displayName: displayName ?? "")
        } catch {
            return HandlerUtilities.errorResult(error)
        }

        do {
            return HandlerUtilities.successResult(try await services.contacts.create(draft))
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    /// Handler for `contacts_update` — updates an existing contact.
    ///
    /// Absent arguments leave their field unchanged; an empty string or empty
    /// array clears it. A supplied collection replaces that collection.
    ///
    /// - Parameters:
    ///   - services: The Apple services container.
    ///   - arguments: MCP arguments containing `id` (required) plus any field to change.
    /// - Returns: JSON object with the updated contact.
    static func updateContact(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        let patch: Contact
        do {
            patch = try Self.contact(from: arguments, id: id, displayName: "")
        } catch {
            return HandlerUtilities.errorResult(error)
        }

        do {
            return HandlerUtilities.successResult(try await services.contacts.update(id: id, patch))
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - Argument Decoding

    /// Builds a `Contact` from MCP arguments, shared by create and update.
    ///
    /// Rejects a singular/plural pair for the same property rather than merging
    /// silently: `email` with `emails` (or `phone` with `phones`) is an
    /// ambiguous request, and guessing which one the caller meant would
    /// silently drop data.
    private static func contact(
        from arguments: [String: Value]?,
        id: String,
        displayName: String
    ) throws -> Contact {
        let email = HandlerUtilities.extractString(from: arguments, key: "email")
        let phone = HandlerUtilities.extractString(from: arguments, key: "phone")
        let emails = try Self.labeledValues(from: arguments, key: "emails")
        let phones = try Self.labeledValues(from: arguments, key: "phones")

        if email != nil, emails != nil {
            throw ValidationError.invalidFormat(field: "email", expected: "either `email` or `emails`, not both")
        }
        if phone != nil, phones != nil {
            throw ValidationError.invalidFormat(field: "phone", expected: "either `phone` or `phones`, not both")
        }

        return Contact(
            id: id,
            displayName: displayName,
            email: email,
            phone: phone,
            givenName: HandlerUtilities.extractString(from: arguments, key: "givenName"),
            familyName: HandlerUtilities.extractString(from: arguments, key: "familyName"),
            organization: HandlerUtilities.extractString(from: arguments, key: "organization"),
            jobTitle: HandlerUtilities.extractString(from: arguments, key: "jobTitle"),
            note: HandlerUtilities.extractString(from: arguments, key: "note"),
            emails: emails,
            phones: phones,
            urls: try Self.labeledValues(from: arguments, key: "urls")
        )
    }

    /// Decodes an array of `{label?, value}` objects.
    ///
    /// Returns `nil` when the key is absent (leave unchanged) and `[]` for an
    /// empty array (clear) — the two must stay distinguishable.
    private static func labeledValues(from arguments: [String: Value]?, key: String) throws -> [LabeledValue]? {
        guard let arguments, let value = arguments[key] else { return nil }
        guard case .array(let entries) = value else {
            throw ValidationError.invalidFormat(field: key, expected: "an array of {label, value} objects")
        }

        return try entries.map { entry in
            switch entry {
            case .string(let plain):
                return LabeledValue(value: plain)
            case .object(let fields):
                guard case .string(let entryValue)? = fields["value"], !entryValue.isEmpty else {
                    throw ValidationError.invalidFormat(field: key, expected: "each entry to carry a non-empty `value`")
                }
                var label: String?
                if case .string(let entryLabel)? = fields["label"], !entryLabel.isEmpty {
                    label = entryLabel
                }
                return LabeledValue(label: label, value: entryValue)
            default:
                throw ValidationError.invalidFormat(field: key, expected: "each entry to be a string or a {label, value} object")
            }
        }
    }
}
