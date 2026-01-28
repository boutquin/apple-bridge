import Foundation
import MCP
import Core

/// MCP handlers for Mail domain tools.
///
/// Provides handlers for the 4 Mail tools:
/// - `mail_search`: Search emails by query
/// - `mail_unread`: Get unread emails
/// - `mail_send`: Send an email
/// - `mail_compose`: Open a new compose window
enum MailHandlers {

    // MARK: - Response Types

    /// Response for successful email send operations.
    private struct SendResponse: Encodable {
        let sent: Bool
        let to: [String]
    }

    /// Response for successful compose operations.
    private struct ComposeResponse: Encodable {
        let composed: Bool
        let opened: Bool
    }

    // MARK: - mail_search

    /// Searches emails matching a query.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: query (required), limit (optional), includeBody (optional).
    /// - Returns: JSON array of matching emails.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func searchEmails(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let query = HandlerUtilities.extractString(from: arguments, key: "query") else {
            return HandlerUtilities.missingRequiredParameter("query")
        }

        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 50
        let includeBody = HandlerUtilities.extractBool(from: arguments, key: "includeBody") ?? false

        do {
            let emails = try await services.mail.search(query: query, limit: limit, includeBody: includeBody)
            return HandlerUtilities.successResult(emails)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - mail_unread

    /// Gets unread emails.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: limit (optional), includeBody (optional).
    /// - Returns: JSON array of unread emails.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func unreadEmails(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 50
        let includeBody = HandlerUtilities.extractBool(from: arguments, key: "includeBody") ?? false

        do {
            let emails = try await services.mail.unread(limit: limit, includeBody: includeBody)
            return HandlerUtilities.successResult(emails)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - mail_send

    /// Sends an email.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: to (required), subject (required), body (required), cc (optional), bcc (optional).
    /// - Returns: Success confirmation.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func sendEmail(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let toArray = extractStringArray(from: arguments, key: "to"), !toArray.isEmpty else {
            return HandlerUtilities.missingRequiredParameter("to")
        }

        guard let subject = HandlerUtilities.extractString(from: arguments, key: "subject") else {
            return HandlerUtilities.missingRequiredParameter("subject")
        }

        guard let body = HandlerUtilities.extractString(from: arguments, key: "body") else {
            return HandlerUtilities.missingRequiredParameter("body")
        }

        let cc = extractStringArray(from: arguments, key: "cc")
        let bcc = extractStringArray(from: arguments, key: "bcc")

        do {
            try await services.mail.send(to: toArray, subject: subject, body: body, cc: cc, bcc: bcc)

            // Return success confirmation using type-safe Encodable
            let response = SendResponse(sent: true, to: toArray)
            return HandlerUtilities.successResult(response)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - mail_compose

    /// Opens a compose window for a new email.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: to (optional), subject (optional), body (optional).
    /// - Returns: Success confirmation.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func composeEmail(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        let to = extractStringArray(from: arguments, key: "to")
        let subject = HandlerUtilities.extractString(from: arguments, key: "subject")
        let body = HandlerUtilities.extractString(from: arguments, key: "body")

        do {
            try await services.mail.compose(to: to, subject: subject, body: body)

            // Return success confirmation using type-safe Encodable
            let response = ComposeResponse(composed: true, opened: true)
            return HandlerUtilities.successResult(response)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - Private Helpers

    /// Extracts a string array from MCP arguments.
    private static func extractStringArray(from arguments: [String: Value]?, key: String) -> [String]? {
        guard let arguments, let value = arguments[key] else { return nil }
        switch value {
        case .array(let array):
            return array.compactMap { element -> String? in
                if case .string(let str) = element {
                    return str
                }
                return nil
            }
        default:
            return nil
        }
    }
}
