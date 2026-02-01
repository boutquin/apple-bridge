import Foundation
import Core

/// AppleScript implementation of `MailAdapterProtocol`.
///
/// Uses AppleScript to interact with Apple Mail for reading, searching,
/// and sending emails. All operations are executed through an `AppleScriptRunnerProtocol`
/// for testability.
///
/// ## Usage
/// ```swift
/// let adapter = AppleScriptMailAdapter()
/// let emails = try await adapter.fetchUnread(limit: 10, includeBody: false)
/// ```
///
/// For testing with a mock runner:
/// ```swift
/// let runner = MockAppleScriptRunner()
/// let adapter = AppleScriptMailAdapter(runner: runner)
/// ```
public struct AppleScriptMailAdapter: MailAdapterProtocol, Sendable {

    /// The AppleScript runner to use for executing scripts.
    private let runner: any AppleScriptRunnerProtocol

    // MARK: - Initialization

    /// Creates a new Mail adapter using the shared AppleScript runner.
    public init() {
        self.runner = AppleScriptRunner.shared
    }

    /// Creates a new Mail adapter with a custom runner (for testing).
    ///
    /// - Parameter runner: The AppleScript runner to use.
    public init(runner: any AppleScriptRunnerProtocol) {
        self.runner = runner
    }

    // MARK: - MailAdapterProtocol

    public func fetchUnread(limit: Int, includeBody: Bool) async throws -> [EmailData] {
        let bodyClause = includeBody ? "content of theMessage" : "\"\""

        // Iterate newest-first by index and collect unread messages up to limit.
        // Uses `message i of inbox` instead of materializing the full collection
        // (`messages of inbox`) — on a 215K inbox, materializing all references
        // causes error -1741 (errAEEventFailed) and locks up Mail.app.
        let script = """
            tell application "Mail"
                set resultList to {}
                set totalCount to count of messages of inbox
                set found to 0
                repeat with i from totalCount to 1 by -1
                    if found ≥ \(limit) then exit repeat
                    set theMessage to message i of inbox
                    if read status of theMessage is false then
                        set found to found + 1
                        set msgId to id of theMessage
                        set msgSubject to subject of theMessage
                        set msgFrom to sender of theMessage
                        try
                            set msgTo to address of first to recipient of theMessage
                        on error
                            set msgTo to ""
                        end try
                        set msgDate to date received of theMessage
                        set msgMailbox to name of mailbox of theMessage
                        set msgBody to \(bodyClause)
                        set end of resultList to (msgId as string) & "\\t" & msgSubject & "\\t" & msgFrom & "\\t" & msgTo & "\\t" & (msgDate as string) & "\\t" & msgMailbox & "\\t" & msgBody & "\\n"
                    end if
                end repeat
                return resultList as string
            end tell
            """

        let result = try await runner.run(script: script, timeout: 30)
        return parseEmailResponse(result, isUnread: true)
    }

    public func searchEmails(query: String, limit: Int, includeBody: Bool) async throws -> [EmailData] {
        let escapedQuery = escapeForAppleScript(query)
        let bodyClause = includeBody ? "content of theMessage" : "\"\""

        // Iterate newest-first by index and match subject only.
        // Uses `message i of inbox` to avoid materializing the full collection.
        // Content search dropped — body scanning via AppleScript is too expensive.
        let script = """
            tell application "Mail"
                set resultList to {}
                set totalCount to count of messages of inbox
                set found to 0
                repeat with i from totalCount to 1 by -1
                    if found ≥ \(limit) then exit repeat
                    set theMessage to message i of inbox
                    set msgSubject to subject of theMessage
                    if msgSubject contains "\(escapedQuery)" then
                        set found to found + 1
                        set msgId to id of theMessage
                        set msgFrom to sender of theMessage
                        try
                            set msgTo to address of first to recipient of theMessage
                        on error
                            set msgTo to ""
                        end try
                        set msgDate to date received of theMessage
                        set msgMailbox to name of mailbox of theMessage
                        set msgIsRead to read status of theMessage
                        set msgBody to \(bodyClause)
                        set end of resultList to (msgId as string) & "\\t" & msgSubject & "\\t" & msgFrom & "\\t" & msgTo & "\\t" & (msgDate as string) & "\\t" & msgMailbox & "\\t" & msgBody & "\\t" & (msgIsRead as string) & "\\n"
                    end if
                end repeat
                return resultList as string
            end tell
            """

        let result = try await runner.run(script: script, timeout: 30)
        return parseSearchResponse(result)
    }

    public func sendEmail(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?) async throws {
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

    public func composeEmail(to: [String]?, subject: String?, body: String?) async throws {
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
    private func parseEmailResponse(_ response: String, isUnread: Bool) -> [EmailData] {
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> EmailData? in
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

            return EmailData(
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
    ///
    /// Expected format: id\tsubject\tfrom\tto\tdate\tmailbox\tbody\tisRead
    /// Requires all 8 fields for proper parsing (body may be empty string).
    private func parseSearchResponse(_ response: String) -> [EmailData] {
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> EmailData? in
            let parts = line.components(separatedBy: "\t")
            // Require all 8 fields: id, subject, from, to, date, mailbox, body, isRead
            guard parts.count >= 8 else { return nil }

            let id = parts[0]
            let subject = parts[1]
            let from = parts[2]
            let to = parts[3]
            let dateString = parts[4]
            let mailbox = parts[5]
            let body = !parts[6].isEmpty ? parts[6] : nil
            let isReadString = parts[7]
            let isUnread = isReadString.lowercased() != "true"

            // Convert AppleScript date to ISO 8601
            let date = convertAppleScriptDate(dateString)

            return EmailData(
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
    ///
    /// - Parameter dateString: The date string from AppleScript (e.g., "Saturday, January 27, 2026 at 10:00:00 AM").
    /// - Returns: ISO 8601 formatted date string, or the original string if parsing fails.
    ///
    /// If parsing fails, returns the original date string rather than losing the data.
    /// This preserves the original information for debugging while still providing a usable value.
    private func convertAppleScriptDate(_ dateString: String) -> String {
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

        // Fallback: return original string to preserve data rather than losing it
        return dateString
    }
}
