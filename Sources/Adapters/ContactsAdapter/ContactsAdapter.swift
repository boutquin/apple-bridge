import Foundation
import AppleBridgeCore

#if canImport(Contacts)
import Contacts
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Contacts framework implementation of `ContactsAdapterProtocol`.
///
/// This adapter provides actual access to the user's contacts through
/// Apple's Contacts framework.
///
/// ## Usage
/// ```swift
/// let adapter = ContactsAdapter()
/// if try await adapter.requestAccess() {
///     let contacts = try await adapter.fetchContacts(query: "John", limit: 10)
/// }
/// ```
///
/// ## Requirements
/// - macOS 10.11+ (uses Contacts framework)
/// - Contacts permission must be granted by the user
public actor ContactsAdapter: ContactsAdapterProtocol {

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

    // MARK: - Write Operations

    public func createContact(_ data: ContactData) async throws -> ContactData {
        #if canImport(Contacts)
        let contact = CNMutableContact()
        Self.apply(data, to: contact, replacingCollections: true, includeNameFallback: true)

        // Name fields only — an organization is not a name.
        guard !contact.givenName.isEmpty || !contact.familyName.isEmpty else {
            throw ValidationError.missingRequired(field: "givenName, familyName, or displayName")
        }

        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        try contactStore.execute(request)
        return try await fetchContact(id: contact.identifier)
        #else
        throw PermissionError.contactsDenied
        #endif
    }

    public func updateContact(id: String, _ data: ContactData) async throws -> ContactData {
        #if canImport(Contacts)
        let existing: CNContact
        do {
            existing = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: Self.contactKeysToFetch)
        } catch CNError.recordDoesNotExist {
            throw ValidationError.notFound(resource: "contact", id: id)
        }

        guard let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ValidationError.notFound(resource: "contact", id: id)
        }
        Self.apply(data, to: mutable, replacingCollections: true, includeNameFallback: false)

        let request = CNSaveRequest()
        request.update(mutable)
        try contactStore.execute(request)
        return try await fetchContact(id: id)
        #else
        throw PermissionError.contactsDenied
        #endif
    }

    #if canImport(Contacts)
    /// Applies the supplied fields to a mutable contact.
    ///
    /// Absent (`nil`) fields are left untouched; supplied ones are written, and
    /// an empty string or empty array clears. `note` is never written — see
    /// ``contactKeysToFetch`` for why this adapter cannot touch notes at all.
    static func apply(
        _ data: ContactData,
        to contact: CNMutableContact,
        replacingCollections: Bool,
        includeNameFallback: Bool
    ) {
        if let givenName = data.givenName { contact.givenName = givenName }
        if let familyName = data.familyName { contact.familyName = familyName }
        if let organization = data.organization { contact.organizationName = organization }
        if let jobTitle = data.jobTitle { contact.jobTitle = jobTitle }

        if includeNameFallback, data.givenName == nil, data.familyName == nil,
           !data.displayName.isEmpty {
            contact.givenName = data.displayName
        }

        if let emails = data.emails {
            contact.emailAddresses = emails.map {
                CNLabeledValue(label: storedLabel($0.label), value: $0.value as NSString)
            }
        }
        if let phones = data.phones {
            contact.phoneNumbers = phones.map {
                CNLabeledValue(label: storedLabel($0.label), value: CNPhoneNumber(stringValue: $0.value))
            }
        }
        if let urls = data.urls {
            contact.urlAddresses = urls.map {
                CNLabeledValue(label: storedLabel($0.label), value: $0.value as NSString)
            }
        }
    }

    // MARK: - Labels

    /// Contacts' standard labels, keyed by the wire form callers use
    /// (`"work"`, `"mobile"`, `"homepage"`, …), matched case-insensitively.
    ///
    /// A caller's `"work"` must be stored as `CNLabelWork` (`_$!<Work>!$_`):
    /// stored literally it becomes a *custom* label spelled "work", which
    /// Contacts.app and every other reader treat as a different label.
    static var standardLabels: [String: String] {
        let constants = [
            CNLabelHome, CNLabelWork, CNLabelSchool, CNLabelOther,
            CNLabelEmailiCloud,
            CNLabelPhoneNumberMobile, CNLabelPhoneNumberiPhone, CNLabelPhoneNumberMain,
            CNLabelPhoneNumberHomeFax, CNLabelPhoneNumberWorkFax, CNLabelPhoneNumberOtherFax,
            CNLabelPhoneNumberPager,
            CNLabelURLAddressHomePage,
        ]
        return Dictionary(
            constants.compactMap { constant in
                wireLabel(constant).map { ($0.lowercased(), constant) }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The label to store for a caller-supplied one: a standard name maps to
    /// its Contacts constant, anything else is kept as a custom label.
    static func storedLabel(_ label: String?) -> String? {
        guard let label, !label.isEmpty else { return nil }
        return standardLabels[label.lowercased()] ?? label
    }

    /// The label to return for a stored one — the same locale-independent
    /// normalization the AppleScript adapter applies, so both conformances emit
    /// `"work"` for `_$!<Work>!$_` on every system language. (The framework's
    /// `localizedString(forLabel:)` would return `"travail"` on a French system.)
    static func wireLabel(_ raw: String?) -> String? {
        raw.flatMap(AppleScriptContactsAdapter.normalizeLabel)
    }
    #endif

    // MARK: - Read Projection

    #if canImport(Contacts)
    /// Keys every read path fetches.
    ///
    /// `CNContactStore` throws if a property is accessed that was not requested
    /// here, so this list and ``contactData(from:)`` must move together — the
    /// single definition is what keeps the three read paths from drifting apart.
    /// Computed rather than stored: `[any CNKeyDescriptor]` is not `Sendable`,
    /// so a `static let` is a strict-concurrency error. Each access builds a
    /// fresh array, which costs nothing at these call rates.
    ///
    /// **`CNContactNoteKey` is deliberately absent.** Reading a contact's note
    /// through the Contacts framework requires the restricted
    /// `com.apple.developer.contacts.notes` entitlement, which Apple grants only
    /// on request and which this app does not carry. Requesting the key does not
    /// fail — the framework simply does not fetch it, and the later
    /// `contact.note` access raises `CNPropertyNotFetchedException`. That is an
    /// Objective-C exception, not a Swift error, so it **terminates the process**
    /// rather than surfacing as a `throw` no `try` can catch it. This adapter
    /// therefore projects `note: nil`, which per the DTO contract means "not
    /// projected" rather than "empty". The wired `AppleScriptContactsAdapter`
    /// reads notes normally over the Automation pathway, so the shipped tools
    /// are unaffected.
    static var contactKeysToFetch: [CNKeyDescriptor] {
        [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]
    }

    /// Projects a fetched `CNContact` into the wire DTO.
    ///
    /// Multi-value properties become empty arrays rather than `nil` when the
    /// contact has none: the projection ran, so "none" is a fact about the
    /// contact, not about what was fetched.
    static func contactData(from contact: CNContact) -> ContactData {
        func labelled<T>(_ values: [CNLabeledValue<T>], _ extract: (T) -> String) -> [LabeledValue] {
            values.map { entry in
                LabeledValue(label: wireLabel(entry.label), value: extract(entry.value))
            }
        }

        return ContactData(
            id: contact.identifier,
            displayName: CNContactFormatter.string(from: contact, style: .fullName) ?? "",
            givenName: contact.givenName.isEmpty ? nil : contact.givenName,
            familyName: contact.familyName.isEmpty ? nil : contact.familyName,
            organization: contact.organizationName.isEmpty ? nil : contact.organizationName,
            jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle,
            note: nil,   // see `contactKeysToFetch` — notes need an Apple-granted entitlement
            emails: labelled(contact.emailAddresses) { $0 as String },
            phones: labelled(contact.phoneNumbers) { $0.stringValue },
            urls: labelled(contact.urlAddresses) { $0 as String }
        )
    }
    #endif

    // MARK: - Contact Operations

    public func fetchContacts(query: String, limit: Int) async throws -> [ContactData] {
        #if canImport(Contacts)
        let keysToFetch = Self.contactKeysToFetch

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
            return Self.contactData(from: contact)
        }
        #else
        throw PermissionError.contactsDenied
        #endif
    }

    public func fetchContact(id: String) async throws -> ContactData {
        #if canImport(Contacts)
        let keysToFetch = Self.contactKeysToFetch

        do {
            let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)

            return Self.contactData(from: contact)
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
