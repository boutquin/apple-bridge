import Foundation

/// Contact model.
public struct Contact: Codable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let email: String?
    public let phone: String?

    public init(
        id: String,
        displayName: String,
        email: String? = nil,
        phone: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.phone = phone
    }
}
