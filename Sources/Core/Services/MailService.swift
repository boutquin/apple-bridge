import Foundation

/// Protocol for interacting with Apple Mail.
///
/// Defines operations for reading, searching, and sending emails.
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Example
/// ```swift
/// let service: MailService = MailAppleScriptService()
/// let emails = try await service.unread(limit: 10, includeBody: false)
/// ```
public protocol MailService: Sendable {

    /// Retrieves unread emails.
    /// - Parameters:
    ///   - limit: Maximum number of emails to return.
    ///   - includeBody: Whether to include email body content.
    /// - Returns: Array of unread emails.
    /// - Throws: `AppleScriptError` if Mail access fails.
    func unread(limit: Int, includeBody: Bool) async throws -> [Email]

    /// Searches for emails matching a query string.
    /// - Parameters:
    ///   - query: Text to search for in email subjects and content.
    ///   - limit: Maximum number of emails to return.
    ///   - includeBody: Whether to include email body content.
    /// - Returns: Array of matching emails.
    /// - Throws: `AppleScriptError` if Mail access fails.
    func search(query: String, limit: Int, includeBody: Bool) async throws -> [Email]

    /// Sends an email.
    /// - Parameters:
    ///   - to: Array of recipient email addresses.
    ///   - subject: Email subject line.
    ///   - body: Email body content.
    ///   - cc: Array of CC email addresses (optional).
    ///   - bcc: Array of BCC email addresses (optional).
    /// - Throws: `AppleScriptError` if sending fails.
    func send(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?) async throws

    /// Opens the Mail app to compose a new email.
    /// - Parameters:
    ///   - to: Pre-filled recipient addresses (optional).
    ///   - subject: Pre-filled subject (optional).
    ///   - body: Pre-filled body (optional).
    /// - Throws: `AppleScriptError` if Mail cannot be opened.
    func compose(to: [String]?, subject: String?, body: String?) async throws
}
