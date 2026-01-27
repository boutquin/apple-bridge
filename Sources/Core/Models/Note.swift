import Foundation

/// Note model.
public struct Note: Codable, Sendable, Equatable {
    public let id: String
    public let title: String?
    public let body: String?
    public let folderId: String?
    public let modifiedAt: String

    public init(
        id: String,
        title: String? = nil,
        body: String? = nil,
        folderId: String? = nil,
        modifiedAt: String
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.folderId = folderId
        self.modifiedAt = modifiedAt
    }
}
