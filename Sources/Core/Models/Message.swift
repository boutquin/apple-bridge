import Foundation

/// Message model (iMessage/SMS).
public struct Message: Codable, Sendable, Equatable {
    public let id: String
    public let chatId: String
    public let sender: String
    public let date: String
    public let body: String?
    public let isUnread: Bool

    public init(
        id: String,
        chatId: String,
        sender: String,
        date: String,
        body: String? = nil,
        isUnread: Bool
    ) {
        self.id = id
        self.chatId = chatId
        self.sender = sender
        self.date = date
        self.body = body
        self.isUnread = isUnread
    }
}
