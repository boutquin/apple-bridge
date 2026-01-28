import Foundation
import Core

// MARK: - Contact Data Transfer Object

/// Lightweight data representation of a CNContact.
///
/// This struct provides a Sendable, Codable representation of contacts
/// that can be safely passed across actor boundaries without requiring direct
/// Contacts framework access.
public struct CNContactData: Sendable, Equatable, Codable {
    /// Unique identifier for the contact.
    public let id: String

    /// Full display name of the contact.
    public let displayName: String

    /// Primary email address, if available.
    public let email: String?

    /// Primary phone number, if available.
    public let phone: String?

    /// Creates a new contact data instance.
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

// MARK: - Protocol

/// Protocol for interacting with Apple Contacts via the Contacts framework.
///
/// This protocol abstracts Contacts framework operations to enable testing with mock implementations.
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Implementation Notes
/// - Real implementations use CNContactStore for contact access
/// - The protocol uses `CNContactData` instead of `CNContact` directly to enable Sendable conformance
///
/// ## Example
/// ```swift
/// let adapter: ContactsAdapterProtocol = RealContactsAdapter()
/// if try await adapter.requestAccess() {
///     let contacts = try await adapter.fetchContacts(query: "John", limit: 10)
/// }
/// ```
public protocol ContactsAdapterProtocol: Sendable {

    // MARK: - Authorization

    /// Requests contacts access from the user.
    /// - Returns: `true` if access is granted, `false` if denied.
    /// - Throws: `PermissionError` if there's an issue requesting access.
    func requestAccess() async throws -> Bool

    // MARK: - Contact Operations

    /// Fetches contacts matching a query.
    /// - Parameters:
    ///   - query: Text to search for in contact names, emails, and phones.
    ///   - limit: Maximum number of contacts to return.
    /// - Returns: Array of matching contact data objects.
    /// - Throws: `PermissionError.contactsDenied` if contacts access is not granted.
    func fetchContacts(query: String, limit: Int) async throws -> [CNContactData]

    /// Fetches a specific contact by identifier.
    /// - Parameter id: The contact identifier.
    /// - Returns: The contact data.
    /// - Throws: `ValidationError.notFound` if the contact doesn't exist.
    func fetchContact(id: String) async throws -> CNContactData

    /// Fetches the user's own contact card (Me card).
    /// - Returns: The user's contact data, or nil if not configured.
    /// - Throws: `PermissionError.contactsDenied` if contacts access is not granted.
    func fetchMeContact() async throws -> CNContactData?

    /// Opens a contact in the Contacts app.
    /// - Parameter id: Contact identifier.
    /// - Throws: `ValidationError.notFound` if the contact doesn't exist.
    func openContact(id: String) async throws
}
