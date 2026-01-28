import Foundation
import Core

#if canImport(Contacts)
import Contacts
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Real implementation of `ContactsAdapterProtocol` using the Contacts framework.
///
/// This adapter provides actual access to the user's contacts through
/// Apple's Contacts framework.
///
/// ## Usage
/// ```swift
/// let adapter = RealContactsAdapter()
/// if try await adapter.requestAccess() {
///     let contacts = try await adapter.fetchContacts(query: "John", limit: 10)
/// }
/// ```
///
/// ## Requirements
/// - macOS 10.11+ (uses Contacts framework)
/// - Contacts permission must be granted by the user
public actor RealContactsAdapter: ContactsAdapterProtocol {

    #if canImport(Contacts)
    /// Shared contact store for contacts access.
    /// Marked nonisolated(unsafe) because CNContactStore handles its own thread safety
    /// and Swift 6's strict concurrency checking doesn't recognize this.
    private nonisolated(unsafe) let contactStore = CNContactStore()
    #endif

    /// Creates a new Contacts adapter.
    public init() {}

    // MARK: - Authorization

    public func requestAccess() async throws -> Bool {
        #if canImport(Contacts)
        return try await contactStore.requestAccess(for: .contacts)
        #else
        throw PermissionError.contactsDenied
        #endif
    }

    // MARK: - Contact Operations

    public func fetchContacts(query: String, limit: Int) async throws -> [ContactData] {
        #if canImport(Contacts)
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        var contacts: [CNContact] = []

        if query.isEmpty {
            // Fetch all contacts
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            try contactStore.enumerateContacts(with: request) { contact, stop in
                contacts.append(contact)
                if contacts.count >= limit {
                    stop.pointee = true
                }
            }
        } else {
            // Search by name
            let predicate = CNContact.predicateForContacts(matchingName: query)
            contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        }

        return contacts.prefix(limit).map { contact in
            let displayName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let email = contact.emailAddresses.first?.value as String?
            let phone = contact.phoneNumbers.first?.value.stringValue

            return ContactData(
                id: contact.identifier,
                displayName: displayName,
                email: email,
                phone: phone
            )
        }
        #else
        throw PermissionError.contactsDenied
        #endif
    }

    public func fetchContact(id: String) async throws -> ContactData {
        #if canImport(Contacts)
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        do {
            let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)

            let displayName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let email = contact.emailAddresses.first?.value as String?
            let phone = contact.phoneNumbers.first?.value.stringValue

            return ContactData(
                id: contact.identifier,
                displayName: displayName,
                email: email,
                phone: phone
            )
        } catch CNError.recordDoesNotExist {
            throw ValidationError.notFound(resource: "contact", id: id)
        }
        #else
        throw PermissionError.contactsDenied
        #endif
    }

    public func fetchMeContact() async throws -> ContactData? {
        #if canImport(Contacts)
        // Note: CNContactStore doesn't have a direct API for "me" card on macOS.
        // Unlike iOS, macOS doesn't support CNContactStore.fetchMeCard().
        // We return nil to indicate no "me" card is available.
        return nil
        #else
        throw PermissionError.contactsDenied
        #endif
    }

    public func openContact(id: String) async throws {
        #if canImport(Contacts) && canImport(AppKit)
        // Verify the contact exists
        let keysToFetch: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor]
        do {
            _ = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
        } catch CNError.recordDoesNotExist {
            throw ValidationError.notFound(resource: "contact", id: id)
        }

        // Open Contacts app
        guard let url = URL(string: "addressbook://") else {
            throw ValidationError.invalidFormat(field: "url", expected: "valid URL scheme")
        }
        NSWorkspace.shared.open(url)
        #else
        throw PermissionError.contactsDenied
        #endif
    }
}
