import Foundation
import AppleBridgeCore

// MARK: - Contact Data Transfer Object

/// Lightweight data representation of a contact.
///
/// This struct provides a Sendable, Codable representation of contacts
/// that can be safely passed across actor boundaries without requiring direct
/// framework access.
public struct ContactData: Sendable, Equatable, Codable {
    /// Unique identifier for the contact.
    public let id: String

    /// Full display name of the contact.
    public let displayName: String

    /// Given (first) name, if available.
    public let givenName: String?

    /// Family (last) name, if available.
    public let familyName: String?

    /// Organization or company name, if available.
    public let organization: String?

    /// Job title, if available.
    public let jobTitle: String?

    /// Free-form note attached to the contact, if available.
    public let note: String?

    /// All email addresses, in Contacts order. `nil` when not projected.
    public let emails: [LabeledValue]?

    /// All phone numbers, in Contacts order. `nil` when not projected.
    public let phones: [LabeledValue]?

    /// All URLs, in Contacts order. `nil` when not projected.
    public let urls: [LabeledValue]?

    /// Primary email address — the first element of ``emails``.
    public var email: String? { emails?.first?.value }

    /// Primary phone number — the first element of ``phones``.
    public var phone: String? { phones?.first?.value }

    /// Creates a new contact data instance.
    ///
    /// Mirrors `Contact` field-for-field: `email` / `phone` are shorthands for a
    /// single unlabelled entry, and a supplied plural wins over its singular.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the contact.
    ///   - displayName: Full display name.
    ///   - email: Shorthand for a single unlabelled email address.
    ///   - phone: Shorthand for a single unlabelled phone number.
    ///   - givenName: Given (first) name.
    ///   - familyName: Family (last) name.
    ///   - organization: Organization or company name.
    ///   - jobTitle: Job title.
    ///   - note: Free-form note.
    ///   - emails: All email addresses, in Contacts order.
    ///   - phones: All phone numbers, in Contacts order.
    ///   - urls: All URLs, in Contacts order.
    public init(
        id: String,
        displayName: String,
        email: String? = nil,
        phone: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        organization: String? = nil,
        jobTitle: String? = nil,
        note: String? = nil,
        emails: [LabeledValue]? = nil,
        phones: [LabeledValue]? = nil,
        urls: [LabeledValue]? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.givenName = givenName
        self.familyName = familyName
        self.organization = organization
        self.jobTitle = jobTitle
        self.note = note
        self.emails = emails ?? email.map { $0.isEmpty ? [] : [LabeledValue(value: $0)] }
        self.phones = phones ?? phone.map { $0.isEmpty ? [] : [LabeledValue(value: $0)] }
        self.urls = urls
    }
}

// MARK: - Protocol

/// Protocol for interacting with Apple Contacts.
///
/// This protocol abstracts contact operations to enable testing with mock implementations.
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Implementation Notes
/// - Real implementations may use CNContactStore, AppleScript, or other mechanisms
/// - The protocol uses `ContactData` DTOs to enable Sendable conformance
///
/// ## Example
/// ```swift
/// let adapter: ContactsAdapterProtocol = ContactsAdapter()
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
    func fetchContacts(query: String, limit: Int) async throws -> [ContactData]

    /// Fetches a specific contact by identifier.
    /// - Parameter id: The contact identifier.
    /// - Returns: The contact data.
    /// - Throws: `ValidationError.notFound` if the contact doesn't exist.
    func fetchContact(id: String) async throws -> ContactData

    /// Fetches the user's own contact card (Me card).
    /// - Returns: The user's contact data, or nil if not configured.
    /// - Throws: `PermissionError.contactsDenied` if contacts access is not granted.
    func fetchMeContact() async throws -> ContactData?

    /// Opens a contact in the Contacts app.
    /// - Parameter id: Contact identifier.
    /// - Throws: `ValidationError.notFound` if the contact doesn't exist.
    func openContact(id: String) async throws

    // MARK: - Write Operations

    /// Creates a new contact.
    ///
    /// The `id` on `data` is **ignored** — the store assigns one, and it is
    /// returned on the result. Every other field is written as supplied.
    ///
    /// Creation is atomic: the person and all of its multi-value entries are
    /// committed in a single save, so a failure part-way leaves no record
    /// behind.
    ///
    /// - Parameter data: The contact to create. At least one of `givenName`,
    ///   `familyName`, or `displayName` must be non-empty.
    /// - Returns: The created contact, carrying the store-assigned identifier.
    /// - Throws: `ValidationError.missingRequired` when no name field is given.
    func createContact(_ data: ContactData) async throws -> ContactData

    /// Updates an existing contact.
    ///
    /// **Absent means unchanged; present means set.** A `nil` field is left
    /// alone; a supplied field replaces the current value, and an empty string
    /// or empty array clears it. A supplied collection **replaces** that
    /// collection rather than appending to it — to add an entry, send the
    /// existing entries alongside the new one.
    ///
    /// - Parameters:
    ///   - id: The identifier of the contact to update.
    ///   - data: The fields to change. Its `id` is ignored in favour of `id`.
    /// - Returns: The contact as it stands after the update.
    /// - Throws: `ValidationError.notFound` if the contact doesn't exist.
    func updateContact(id: String, _ data: ContactData) async throws -> ContactData
}
