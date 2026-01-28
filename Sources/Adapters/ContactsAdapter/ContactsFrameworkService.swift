import Foundation
import Core

/// Implementation of `ContactsService` using the Contacts framework via an adapter.
///
/// This service translates between the high-level `ContactsService` protocol
/// and the lower-level `ContactsAdapterProtocol`.
///
/// ## Example
/// ```swift
/// let adapter = RealContactsAdapter()
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

    public func search(query: String, limit: Int) async throws -> [Contact] {
        let contacts = try await adapter.fetchContacts(query: query, limit: limit)
        return contacts.map(convertToContact)
    }

    public func get(id: String) async throws -> Contact {
        let contact = try await adapter.fetchContact(id: id)
        return convertToContact(contact)
    }

    public func me() async throws -> Contact? {
        guard let contact = try await adapter.fetchMeContact() else {
            return nil
        }
        return convertToContact(contact)
    }

    public func open(id: String) async throws {
        try await adapter.openContact(id: id)
    }

    // MARK: - Private Helpers

    /// Converts a `CNContactData` to a `Contact`.
    private func convertToContact(_ data: CNContactData) -> Contact {
        Contact(
            id: data.id,
            displayName: data.displayName,
            email: data.email,
            phone: data.phone
        )
    }
}
