import Foundation
import Core

// MARK: - Mail Data Transfer Objects

/// Lightweight data representation of an email.
///
/// This struct provides a Sendable, Codable representation of emails
/// that can be safely passed across actor boundaries without requiring direct
/// framework access. Used as the boundary type between adapter implementations
/// (AppleScript, etc.) and the service layer.
public struct EmailData: Sendable, Equatable, Codable {
    /// Unique identifier for the email.
    public let id: String

    /// Subject line of the email.
    public let subject: String

    /// Sender's email address.
    public let from: String

    /// Recipient email addresses.
    public let to: [String]

    /// Email timestamp in ISO 8601 format.
    public let date: String

    /// Email body content, if included.
    public let body: String?

    /// Mailbox containing this email.
    public let mailbox: String?

    /// Whether this email is unread.
    public let isUnread: Bool

    /// Creates a new email data instance.
    /// - Parameters:
    ///   - id: Unique identifier for the email.
    ///   - subject: Subject line.
    ///   - from: Sender's email address.
    ///   - to: Recipient email addresses.
    ///   - date: Email timestamp in ISO 8601 format.
    ///   - body: Email body content.
    ///   - mailbox: Containing mailbox.
    ///   - isUnread: Whether the email is unread.
    public init(
        id: String,
        subject: String,
        from: String,
        to: [String],
        date: String,
        body: String? = nil,
        mailbox: String? = nil,
        isUnread: Bool = false
    ) {
        self.id = id
        self.subject = subject
        self.from = from
        self.to = to
        self.date = date
        self.body = body
        self.mailbox = mailbox
        self.isUnread = isUnread
    }
}

/// Lightweight data representation of a mailbox.
///
/// This struct provides a Sendable representation of mailboxes that can be
/// safely passed across actor boundaries. Used as the boundary type between
/// adapter implementations and the service layer.
public struct MailboxData: Sendable, Equatable, Codable {
    /// Unique identifier for the mailbox.
    public let id: String

    /// Display name of the mailbox.
    public let name: String

    /// Number of unread messages in the mailbox.
    public let unreadCount: Int

    /// Creates a new mailbox data instance.
    /// - Parameters:
    ///   - id: Unique identifier for the mailbox.
    ///   - name: Display name of the mailbox.
    ///   - unreadCount: Number of unread messages.
    public init(id: String, name: String, unreadCount: Int = 0) {
        self.id = id
        self.name = name
        self.unreadCount = unreadCount
    }
}

// MARK: - Protocol

/// Protocol for interacting with Apple Mail.
///
/// This protocol abstracts mail operations to enable testing with mock implementations
/// and to support multiple backend implementations (AppleScript, etc.).
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Implementation Notes
/// - AppleScript implementation uses osascript for mail access
/// - The protocol uses generic data transfer objects (EmailData, MailboxData) to
///   decouple from specific implementation details
///
/// ## Example
/// ```swift
/// let adapter: MailAdapterProtocol = RealMailAdapter()
/// let emails = try await adapter.fetchUnread(limit: 10, includeBody: false)
/// ```
public protocol MailAdapterProtocol: Sendable {

    // MARK: - Fetch Operations

    /// Fetches unread emails.
    /// - Parameters:
    ///   - limit: Maximum number of emails to return.
    ///   - includeBody: Whether to include email body content.
    /// - Returns: Array of unread email data objects.
    /// - Throws: `AppleScriptError` if Mail access fails.
    func fetchUnread(limit: Int, includeBody: Bool) async throws -> [EmailData]

    /// Searches for emails matching a query string.
    /// - Parameters:
    ///   - query: Text to search for in email subjects and content.
    ///   - limit: Maximum number of emails to return.
    ///   - includeBody: Whether to include email body content.
    /// - Returns: Array of matching email data objects.
    /// - Throws: `AppleScriptError` if Mail access fails.
    func searchEmails(query: String, limit: Int, includeBody: Bool) async throws -> [EmailData]

    // MARK: - Send Operations

    /// Sends an email.
    /// - Parameters:
    ///   - to: Array of recipient email addresses.
    ///   - subject: Email subject line.
    ///   - body: Email body content.
    ///   - cc: Array of CC email addresses (optional).
    ///   - bcc: Array of BCC email addresses (optional).
    /// - Throws: `AppleScriptError` if sending fails.
    func sendEmail(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?) async throws

    /// Opens the Mail app to compose a new email.
    /// - Parameters:
    ///   - to: Pre-filled recipient addresses (optional).
    ///   - subject: Pre-filled subject (optional).
    ///   - body: Pre-filled body (optional).
    /// - Throws: `AppleScriptError` if Mail cannot be opened.
    func composeEmail(to: [String]?, subject: String?, body: String?) async throws
}
