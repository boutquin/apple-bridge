import Foundation
import Core

/// Mock implementation of `ContactsService` for testing.
public actor MockContactsService: ContactsService {

    /// Stubbed contacts to return from search operations.
    public var stubContacts: [Contact] = []

    /// Stubbed Me contact (user's contact card).
    public var stubMeContact: Contact?

    /// Tracks IDs of contacts that have been opened.
    public var openedContactIds: [String] = []

    /// Error to throw (if set) for testing error scenarios.
    public var errorToThrow: (any Error)?

    /// Creates a new mock contacts service.
    public init() {}

    /// Sets stubbed contacts for testing.
    public func setStubContacts(_ contacts: [Contact]) {
        self.stubContacts = contacts
    }

    /// Sets the stubbed Me contact for testing.
    public func setStubMeContact(_ contact: Contact?) {
        self.stubMeContact = contact
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    public func search(query: String, limit: Int) async throws -> [Contact] {
        if let error = errorToThrow { throw error }

        let filtered = stubContacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(query) ||
            (contact.email?.localizedCaseInsensitiveContains(query) ?? false) ||
            (contact.phone?.localizedCaseInsensitiveContains(query) ?? false)
        }

        return Array(filtered.prefix(limit))
    }

    public func get(id: String) async throws -> Contact {
        if let error = errorToThrow { throw error }

        guard let contact = stubContacts.first(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Contact", id: id)
        }

        return contact
    }

    public func me() async throws -> Contact? {
        if let error = errorToThrow { throw error }
        return stubMeContact
    }

    public func open(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard stubContacts.contains(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Contact", id: id)
        }

        openedContactIds.append(id)
    }
}
