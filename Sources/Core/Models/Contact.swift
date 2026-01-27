import Foundation

/// A contact from Apple Contacts.
///
/// Represents a person with their basic contact information.
///
/// ## Example
/// ```swift
/// let contact = Contact(
///     id: "C123",
///     displayName: "John Doe",
///     email: "john@example.com",
///     phone: "+1-555-0100"
/// )
/// ```
public struct Contact: Codable, Sendable, Equatable {
    /// Unique identifier for the contact.
    public let id: String

    /// Full display name of the contact.
    public let displayName: String

    /// Primary email address, if available.
    public let email: String?

    /// Primary phone number, if available.
    public let phone: String?

    /// Creates a new contact.
    /// - Parameters:
    ///   - id: Unique identifier for the contact.
    ///   - displayName: Full display name.
    ///   - email: Primary email address.
    ///   - phone: Primary phone number.
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
