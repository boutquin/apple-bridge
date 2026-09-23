import Foundation
import Core
import Adapters

/// Mock implementation of `ContactsAdapterProtocol` for testing.
///
/// Provides stubbed data and tracks method calls for verification in tests.
/// All methods are actor-isolated for thread safety.
public actor MockContactsAdapter: ContactsAdapterProtocol {

    // MARK: - Stub Data

    /// Whether contacts access is granted.
    private var accessGranted: Bool = true

    /// Stubbed contacts to return from fetch operations.
    private var stubContacts: [ContactData] = []

    /// Stubbed Me contact (user's contact card).
    private var stubMeContact: ContactData?

    /// Error to throw (if set) for testing error scenarios.
    private var errorToThrow: (any Error)?

    // MARK: - Tracking

    /// Tracks IDs of contacts that have been opened.
    private var openedContactIds: [String] = []

    // MARK: - Initialization

    /// Creates a new mock contacts adapter.
    public init() {}

    // MARK: - Setup Methods

    /// Sets whether contacts access is granted.
    public func setAccessGranted(_ granted: Bool) {
        self.accessGranted = granted
    }

    /// Sets stubbed contacts for testing.
    public func setStubContacts(_ contacts: [ContactData]) {
        self.stubContacts = contacts
    }

    /// Sets the stubbed Me contact for testing.
    public func setStubMeContact(_ contact: ContactData?) {
        self.stubMeContact = contact
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    // MARK: - Verification Methods

    /// Gets the list of opened contact IDs for verification.
    public func getOpenedContactIds() -> [String] {
        return openedContactIds
    }

    // MARK: - ContactsAdapterProtocol

    public func requestAccess() async throws -> Bool {
        if let error = errorToThrow { throw error }
        return accessGranted
    }

    public func fetchContacts(query: String, limit: Int) async throws -> [ContactData] {
        if let error = errorToThrow { throw error }

        // Filter by query (case-insensitive search in displayName, email, phone)
        let filtered = stubContacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(query) ||
            (contact.email?.localizedCaseInsensitiveContains(query) ?? false) ||
            (contact.phone?.localizedCaseInsensitiveContains(query) ?? false)
        }

        return Array(filtered.prefix(limit))
    }

    public func fetchContact(id: String) async throws -> ContactData {
        if let error = errorToThrow { throw error }

        guard let contact = stubContacts.first(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Contact", id: id)
        }

        return contact
    }

    public func fetchMeContact() async throws -> ContactData? {
        if let error = errorToThrow { throw error }
        return stubMeContact
    }

    public func openContact(id: String) async throws {
        if let error = errorToThrow { throw error }

        guard stubContacts.contains(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "Contact", id: id)
        }

        openedContactIds.append(id)
    }

    // MARK: - Write Operations

    /// Records every create/update call so tests can assert on what was sent.
    public private(set) var createdContacts: [ContactData] = []
    public private(set) var updatedContacts: [(id: String, data: ContactData)] = []

    public func createContact(_ data: ContactData) async throws -> ContactData {
        if let errorToThrow { throw errorToThrow }
        guard data.givenName?.isEmpty == false || data.familyName?.isEmpty == false
                || !data.displayName.isEmpty else {
            throw ValidationError.missingRequired(field: "givenName, familyName, or displayName")
        }
        createdContacts.append(data)

        let created = ContactData(
            id: "mock-\(createdContacts.count)",
            displayName: data.displayName.isEmpty
                ? [data.givenName, data.familyName].compactMap { $0 }.joined(separator: " ")
                : data.displayName,
            givenName: data.givenName,
            familyName: data.familyName,
            organization: data.organization,
            jobTitle: data.jobTitle,
            note: data.note,
            emails: data.emails ?? [],
            phones: data.phones ?? [],
            urls: data.urls ?? []
        )
        stubContacts.append(created)
        return created
    }

    public func updateContact(id: String, _ data: ContactData) async throws -> ContactData {
        if let errorToThrow { throw errorToThrow }
        updatedContacts.append((id: id, data: data))

        guard let index = stubContacts.firstIndex(where: { $0.id == id }) else {
            throw ValidationError.notFound(resource: "contact", id: id)
        }

        // Mirrors the real adapters: absent leaves alone, supplied replaces.
        let existing = stubContacts[index]
        let merged = ContactData(
            id: existing.id,
            displayName: existing.displayName,
            givenName: data.givenName ?? existing.givenName,
            familyName: data.familyName ?? existing.familyName,
            organization: data.organization ?? existing.organization,
            jobTitle: data.jobTitle ?? existing.jobTitle,
            note: data.note ?? existing.note,
            emails: data.emails ?? existing.emails,
            phones: data.phones ?? existing.phones,
            urls: data.urls ?? existing.urls
        )
        stubContacts[index] = merged
        return merged
    }
}
