import Foundation

/// Email model.
public struct Email: Codable, Sendable, Equatable {
    public let id: String
    public let subject: String
    public let from: String
    public let to: [String]
    public let date: String
    public let body: String?
    public let mailbox: String?
    public let isUnread: Bool

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
