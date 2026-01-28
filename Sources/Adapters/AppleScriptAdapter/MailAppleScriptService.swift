import Foundation
import Core

/// AppleScript-based implementation of `MailService`.
///
/// Uses a `MailAdapterProtocol` to interact with Apple Mail for reading,
/// searching, and sending emails. This enables dependency injection for testing.
///
/// ## Usage
/// ```swift
/// let service = MailAppleScriptService()
/// let emails = try await service.unread(limit: 10, includeBody: false)
/// ```
///
/// For testing with a mock adapter:
/// ```swift
/// let adapter = MockMailAdapter()
/// let service = MailAppleScriptService(adapter: adapter)
/// ```
public struct MailAppleScriptService: MailService, Sendable {

    /// The adapter to use for mail operations.
    private let adapter: any MailAdapterProtocol

    // MARK: - Initialization

    /// Creates a new Mail service using the default adapter.
    public init() {
        self.adapter = RealMailAdapter()
    }

    /// Creates a new Mail service with a custom adapter (for testing).
    ///
    /// - Parameter adapter: The mail adapter to use.
    public init(adapter: any MailAdapterProtocol) {
        self.adapter = adapter
    }

    /// Creates a new Mail service with a custom runner (for backward compatibility).
    ///
    /// - Parameter runner: The AppleScript runner to use.
    public init(runner: any AppleScriptRunnerProtocol) {
        self.adapter = RealMailAdapter(runner: runner)
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
        let emailData = try await adapter.fetchUnread(limit: limit, includeBody: includeBody)
        return emailData.map { toEmail($0) }
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
        let emailData = try await adapter.searchEmails(query: query, limit: limit, includeBody: includeBody)
        return emailData.map { toEmail($0) }
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
        try await adapter.sendEmail(to: to, subject: subject, body: body, cc: cc, bcc: bcc)
    }

    /// Opens the Mail app to compose a new email.
    ///
    /// - Parameters:
    ///   - to: Pre-filled recipient addresses (optional).
    ///   - subject: Pre-filled subject (optional).
    ///   - body: Pre-filled body (optional).
    /// - Throws: `AppleScriptError` if Mail cannot be opened.
    public func compose(to: [String]?, subject: String?, body: String?) async throws {
        try await adapter.composeEmail(to: to, subject: subject, body: body)
    }

    // MARK: - Private Helpers

    /// Converts EmailData to Email model.
    private func toEmail(_ data: EmailData) -> Email {
        Email(
            id: data.id,
            subject: data.subject,
            from: data.from,
            to: data.to,
            date: data.date,
            body: data.body,
            mailbox: data.mailbox,
            isUnread: data.isUnread
        )
    }
}
