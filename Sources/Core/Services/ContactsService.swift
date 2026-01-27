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
}
