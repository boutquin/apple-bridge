import Foundation
import Core

/// Implementation of `ContactsService` using the Contacts framework via an adapter.
///
/// This service translates between the high-level `ContactsService` protocol
/// and the lower-level `ContactsAdapterProtocol`.
///
/// ## Example
/// ```swift
/// let adapter = ContactsAdapter()
/// let service = ContactsFrameworkService(adapter: adapter)
/// let contacts = try await service.search(query: "John", limit: 10)
/// ```
public struct ContactsFrameworkService: ContactsService, Sendable {

    /// The adapter used to interact with the Contacts framework.
    private let adapter: any ContactsAdapterProtocol

    /// Creates a new contacts service with the given adapter.
    /// - Parameter adapter: The Contacts adapter to use for contact operations.
    public init(adapter: any ContactsAdapterProtocol) {
        self.adapter = adapter
    }

    // MARK: - ContactsService Protocol

    /// Searches contacts matching a query string.
    /// - Parameters:
    ///   - query: Text to search in contact names, emails, and phones.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Array of matching contacts.
    /// - Throws: `PermissionError.contactsDenied` if contacts access is not granted.
    public func search(query: String, limit: Int) async throws -> [Contact] {
        let contacts = try await adapter.fetchContacts(query: query, limit: limit)
        return contacts.map(convertToContact)
    }

    /// Retrieves a contact by identifier.
    /// - Parameter id: The contact identifier.
    /// - Returns: The contact with the given ID.
    /// - Throws: `ValidationError.notFound` if the contact doesn't exist.
    public func get(id: String) async throws -> Contact {
        let contact = try await adapter.fetchContact(id: id)
        return convertToContact(contact)
    }

    /// Retrieves the user's own contact card (Me card).
    /// - Returns: The user's contact, or `nil` if not configured in Contacts.
    /// - Throws: `PermissionError.contactsDenied` if contacts access is not granted.
    public func me() async throws -> Contact? {
        guard let contact = try await adapter.fetchMeContact() else {
            return nil
        }
        return convertToContact(contact)
    }

    /// Opens a contact in the Contacts app.
    /// - Parameter id: The contact identifier.
    /// - Throws: `ValidationError.notFound` if the contact doesn't exist.
    public func open(id: String) async throws {
        try await adapter.openContact(id: id)
    }

    // MARK: - Private Helpers

    /// Converts a `ContactData` to a `Contact`.
    private func convertToContact(_ data: ContactData) -> Contact {
        Contact(
            id: data.id,
            displayName: data.displayName,
            email: data.email,
            phone: data.phone
        )
    }
}
