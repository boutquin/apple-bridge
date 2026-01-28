import Foundation
import Core

/// AppleScript-based implementation of `MailService`.
///
/// Uses AppleScript to interact with Apple Mail for reading, searching,
/// and sending emails. All operations are executed through an `AppleScriptRunnerProtocol`
/// for testability.
///
/// ## Usage
/// ```swift
/// let service = MailAppleScriptService()
/// let emails = try await service.unread(limit: 10, includeBody: false)
/// ```
///
/// For testing with a mock runner:
/// ```swift
/// let runner = MockAppleScriptRunner()
/// let service = MailAppleScriptService(runner: runner)
/// ```
public struct MailAppleScriptService: MailService, Sendable {

    /// The AppleScript runner to use for executing scripts.
    private let runner: any AppleScriptRunnerProtocol

    // MARK: - Initialization

    /// Creates a new Mail service using the shared AppleScript runner.
    public init() {
        self.runner = AppleScriptRunner.shared
    }

    /// Creates a new Mail service with a custom runner (for testing).
    ///
    /// - Parameter runner: The AppleScript runner to use.
    public init(runner: any AppleScriptRunnerProtocol) {
        self.runner = runner
    }

    // MARK: - MailService Protocol

    /// Retrieves unread emails.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of emails to return.
    ///   - includeBody: Whether to include email body content.
    /// - Returns: Array of unread emails.
    /// - Throws: `AppleScriptError` if Mail access fails.
    public func unread(limit: Int, includeBody: Bool) async throws -> [Email] {
        let bodyClause = includeBody ? "content of theMessage" : "\"\""

        let script = """
            tell application "Mail"
                set resultList to {}
                set unreadMessages to (messages of inbox whose read status is false)
                set msgCount to count of unreadMessages
                if msgCount > \(limit) then set msgCount to \(limit)
                repeat with i from 1 to msgCount
                    set theMessage to item i of unreadMessages
                    set msgId to id of theMessage
                    set msgSubject to subject of theMessage
                    set msgFrom to sender of theMessage
                    set msgTo to address of first to recipient of theMessage
                    set msgDate to date received of theMessage
                    set msgMailbox to name of mailbox of theMessage
                    set msgBody to \(bodyClause)
                    set end of resultList to (msgId as string) & "\\t" & msgSubject & "\\t" & msgFrom & "\\t" & msgTo & "\\t" & (msgDate as string) & "\\t" & msgMailbox & "\\t" & msgBody & "\\n"
                end repeat
                return resultList as string
            end tell
            """

        let result = try await runner.run(script: script)
        return parseEmailResponse(result, isUnread: true)
    }

    /// Searches for emails matching a query string.
    ///
    /// - Parameters:
    ///   - query: Text to search for in email subjects and content.
    ///   - limit: Maximum number of emails to return.
    ///   - includeBody: Whether to include email body content.
    /// - Returns: Array of matching emails.
    /// - Throws: `AppleScriptError` if Mail access fails.
    public func search(query: String, limit: Int, includeBody: Bool) async throws -> [Email] {
        let escapedQuery = escapeForAppleScript(query)
        let bodyClause = includeBody ? "content of theMessage" : "\"\""

        let script = """
            tell application "Mail"
                set resultList to {}
                set allMessages to (messages of inbox whose subject contains "\(escapedQuery)" or content contains "\(escapedQuery)")
                set msgCount to count of allMessages
                if msgCount > \(limit) then set msgCount to \(limit)
                repeat with i from 1 to msgCount
                    set theMessage to item i of allMessages
                    set msgId to id of theMessage
                    set msgSubject to subject of theMessage
                    set msgFrom to sender of theMessage
                    set msgTo to address of first to recipient of theMessage
                    set msgDate to date received of theMessage
                    set msgMailbox to name of mailbox of theMessage
                    set msgIsRead to read status of theMessage
                    set msgBody to \(bodyClause)
                    set end of resultList to (msgId as string) & "\\t" & msgSubject & "\\t" & msgFrom & "\\t" & msgTo & "\\t" & (msgDate as string) & "\\t" & msgMailbox & "\\t" & msgBody & "\\t" & (msgIsRead as string) & "\\n"
                end repeat
                return resultList as string
            end tell
            """

        let result = try await runner.run(script: script)
        return parseSearchResponse(result)
    }

    /// Sends an email.
    ///
    /// - Parameters:
    ///   - to: Array of recipient email addresses.
    ///   - subject: Email subject line.
    ///   - body: Email body content.
    ///   - cc: Array of CC email addresses (optional).
    ///   - bcc: Array of BCC email addresses (optional).
    /// - Throws: `AppleScriptError` if sending fails.
    public func send(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?) async throws {
        let escapedSubject = escapeForAppleScript(subject)
        let escapedBody = escapeForAppleScript(body)

        var recipientCommands = ""
        for recipient in to {
            let escapedTo = escapeForAppleScript(recipient)
            recipientCommands += """
                        make new to recipient at end of to recipients with properties {address:"\(escapedTo)"}

            """
        }

        if let ccList = cc {
            for ccRecipient in ccList {
                let escapedCc = escapeForAppleScript(ccRecipient)
                recipientCommands += """
                        make new cc recipient at end of cc recipients with properties {address:"\(escapedCc)"}

            """
            }
        }

        if let bccList = bcc {
            for bccRecipient in bccList {
                let escapedBcc = escapeForAppleScript(bccRecipient)
                recipientCommands += """
                        make new bcc recipient at end of bcc recipients with properties {address:"\(escapedBcc)"}

            """
            }
        }

        let script = """
            tell application "Mail"
                set newMessage to make new outgoing message with properties {subject:"\(escapedSubject)", content:"\(escapedBody)", visible:false}
                tell newMessage
            \(recipientCommands)
                end tell
                send newMessage
            end tell
            """

        _ = try await runner.run(script: script)
    }

    /// Opens the Mail app to compose a new email.
    ///
    /// - Parameters:
    ///   - to: Pre-filled recipient addresses (optional).
    ///   - subject: Pre-filled subject (optional).
    ///   - body: Pre-filled body (optional).
    /// - Throws: `AppleScriptError` if Mail cannot be opened.
    public func compose(to: [String]?, subject: String?, body: String?) async throws {
        var properties: [String] = []

        if let subject = subject {
            properties.append("subject:\"\(escapeForAppleScript(subject))\"")
        }
        if let body = body {
            properties.append("content:\"\(escapeForAppleScript(body))\"")
        }
        properties.append("visible:true")

        let propertiesString = properties.joined(separator: ", ")

        var recipientCommands = ""
        if let toList = to {
            for recipient in toList {
                let escapedTo = escapeForAppleScript(recipient)
                recipientCommands += """
                    make new to recipient at end of to recipients with properties {address:"\(escapedTo)"}

                """
            }
        }

        let script = """
            tell application "Mail"
                activate
                set newMessage to make new outgoing message with properties {\(propertiesString)}
                tell newMessage
            \(recipientCommands)
                end tell
            end tell
            """

        _ = try await runner.run(script: script)
    }

    // MARK: - Private Helpers

    /// Escapes a string for use in AppleScript.
    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Parses the AppleScript response for unread emails.
    private func parseEmailResponse(_ response: String, isUnread: Bool) -> [Email] {
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> Email? in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 6 else { return nil }

            let id = parts[0]
            let subject = parts[1]
            let from = parts[2]
            let to = parts[3]
            let dateString = parts[4]
            let mailbox = parts[5]
            let body = parts.count > 6 && !parts[6].isEmpty ? parts[6] : nil

            // Convert AppleScript date to ISO 8601
            let date = convertAppleScriptDate(dateString)

            return Email(
                id: id,
                subject: subject,
                from: from,
                to: [to],
                date: date,
                body: body,
                mailbox: mailbox,
                isUnread: isUnread
            )
        }
    }

    /// Parses the AppleScript response for search results.
    private func parseSearchResponse(_ response: String) -> [Email] {
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> Email? in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 7 else { return nil }

            let id = parts[0]
            let subject = parts[1]
            let from = parts[2]
            let to = parts[3]
            let dateString = parts[4]
            let mailbox = parts[5]
            let body = parts.count > 6 && !parts[6].isEmpty ? parts[6] : nil
            let isReadString = parts.count > 7 ? parts[7] : "true"
            let isUnread = isReadString.lowercased() != "true"

            // Convert AppleScript date to ISO 8601
            let date = convertAppleScriptDate(dateString)

            return Email(
                id: id,
                subject: subject,
                from: from,
                to: [to],
                date: date,
                body: body,
                mailbox: mailbox,
                isUnread: isUnread
            )
        }
    }

    /// Converts an AppleScript date string to ISO 8601 format.
    private func convertAppleScriptDate(_ dateString: String) -> String {
        // AppleScript returns dates like "Saturday, January 27, 2026 at 10:00:00 AM"
        // We need to convert to ISO 8601 format
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try common AppleScript date formats
        let formats = [
            "EEEE, MMMM d, yyyy 'at' h:mm:ss a",
            "EEEE, MMMM d, yyyy, h:mm:ss a",
            "MMMM d, yyyy 'at' h:mm:ss a",
            "yyyy-MM-dd HH:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime]
                return isoFormatter.string(from: date)
            }
        }

        // Fallback: return current date in ISO format
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.string(from: Date())
    }
}
