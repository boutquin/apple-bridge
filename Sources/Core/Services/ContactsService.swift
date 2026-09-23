import Foundation

/// Protocol for interacting with Apple Contacts.
///
/// Defines operations for searching, retrieving, and opening contacts.
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Example
/// ```swift
/// let service: ContactsService = ContactsFrameworkService()
/// let contacts = try await service.search(query: "John", limit: 10)
/// ```
public protocol ContactsService: Sendable {

    /// Searches for contacts matching a query string.
    /// - Parameters:
    ///   - query: Text to search for in contact names and other fields.
    ///   - limit: Maximum number of contacts to return.
    /// - Returns: Array of matching contacts.
    /// - Throws: `PermissionError.contactsDenied` if contacts access is not granted.
    func search(query: String, limit: Int) async throws -> [Contact]

    /// Retrieves a specific contact by its identifier.
    /// - Parameter id: Unique identifier of the contact.
    /// - Returns: The contact.
    /// - Throws: `ValidationError.notFound` if the contact is not found.
    func get(id: String) async throws -> Contact

    /// Retrieves the user's own contact card (Me card).
    /// - Returns: The user's contact, or nil if not configured.
    /// - Throws: `PermissionError.contactsDenied` if contacts access is not granted.
    func me() async throws -> Contact?

    /// Opens a contact in the Contacts app.
    /// - Parameter id: Unique identifier of the contact to open.
    /// - Throws: `ValidationError.notFound` if the contact is not found.
    func open(id: String) async throws

    // MARK: - Write Operations

    /// Creates a new contact.
    ///
    /// The `id` on `contact` is ignored — the store assigns one.
    ///
    /// - Parameter contact: The contact to create. At least one of `givenName`,
    ///   `familyName`, or `displayName` must be non-empty.
    /// - Returns: The created contact, carrying the store-assigned identifier.
    /// - Throws: `ValidationError.missingRequired` when no name field is given.
    func create(_ contact: Contact) async throws -> Contact

    /// Updates an existing contact.
    ///
    /// Absent fields are left unchanged; supplied fields are written, and an
    /// empty string or empty array clears. A supplied collection replaces that
    /// collection rather than appending to it.
    ///
    /// - Parameters:
    ///   - id: The identifier of the contact to update.
    ///   - contact: The fields to change; its `id` is ignored in favour of `id`.
    /// - Returns: The contact as it stands after the update.
    /// - Throws: `ValidationError.notFound` if the contact doesn't exist.
    func update(id: String, _ contact: Contact) async throws -> Contact
}
