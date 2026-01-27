import Foundation

/// An email from Apple Mail.
///
/// Represents a single email with its headers, content, and read status.
///
/// ## Example
/// ```swift
/// let email = Email(
///     id: "E123",
///     subject: "Meeting Tomorrow",
///     from: "boss@company.com",
///     to: ["team@company.com"],
///     date: "2024-01-28T10:00:00Z",
///     body: "Let's meet at 10am.",
///     mailbox: "INBOX",
///     isUnread: true
/// )
/// ```
public struct Email: Codable, Sendable, Equatable {
    /// Unique identifier for the email.
    public let id: String

    /// Subject line of the email.
    public let subject: String

    /// Sender's email address.
    public let from: String

    /// List of recipient email addresses.
    public let to: [String]

    /// Date/time the email was sent in ISO 8601 format.
    public let date: String

    /// Body content of the email.
    public let body: String?

    /// Name of the mailbox containing this email (e.g., "INBOX").
    public let mailbox: String?

    /// Whether the email has been read.
    public let isUnread: Bool

    /// Creates a new email.
    /// - Parameters:
    ///   - id: Unique identifier for the email.
    ///   - subject: Subject line.
    ///   - from: Sender's email address.
    ///   - to: List of recipient addresses.
    ///   - date: Send timestamp in ISO 8601 format.
    ///   - body: Body content.
    ///   - mailbox: Name of the containing mailbox.
    ///   - isUnread: Whether the email is unread.
    public init(
        id: String,
        subject: String,
        from: String,
        to: [String],
        date: String,
        body: String? = nil,
        mailbox: String? = nil,
        isUnread: Bool
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
