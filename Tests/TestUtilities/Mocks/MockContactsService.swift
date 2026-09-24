import Foundation
import AppleBridgeCore

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

    // MARK: - Write Operations

    /// Records every create/update call so tests can assert on what was sent.
    public private(set) var createdContacts: [Contact] = []
    public private(set) var updatedContacts: [(id: String, contact: Contact)] = []

    public func create(_ contact: Contact) async throws -> Contact {
        if let error = errorToThrow { throw error }
        createdContacts.append(contact)

        guard contact.givenName?.isEmpty == false || contact.familyName?.isEmpty == false
                || !contact.displayName.isEmpty else {
            throw ValidationError.missingRequired(field: "givenName, familyName, or displayName")
        }

        let created = Contact(
            id: "mock-contact-\(createdContacts.count)",
            displayName: contact.displayName.isEmpty
                ? [contact.givenName, contact.familyName].compactMap { $0 }.joined(separator: " ")
                : contact.displayName,
            givenName: contact.givenName,
            familyName: contact.familyName,
            organization: contact.organization,
            jobTitle: contact.jobTitle,
            note: contact.note,
            emails: contact.emails ?? [],
            phones: contact.phones ?? [],
            urls: contact.urls ?? []
        )
        stubContacts.append(created)
        return created
    }

    public func update(id: String, _ contact: Contact) async throws -> Contact {
        if let error = errorToThrow { throw error }
        updatedContacts.append((id: id, contact: contact))

        guard let index = stubContacts.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Contact", id: id)
        }

        let existing = stubContacts[index]
        let merged = Contact(
            id: existing.id,
            displayName: existing.displayName,
            givenName: contact.givenName ?? existing.givenName,
            familyName: contact.familyName ?? existing.familyName,
            organization: contact.organization ?? existing.organization,
            jobTitle: contact.jobTitle ?? existing.jobTitle,
            note: contact.note ?? existing.note,
            emails: contact.emails ?? existing.emails,
            phones: contact.phones ?? existing.phones,
            urls: contact.urls ?? existing.urls
        )
        stubContacts[index] = merged
        return merged
    }
}
