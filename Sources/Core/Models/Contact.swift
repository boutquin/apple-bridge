import Foundation

/// One labelled entry of an Apple Contacts multi-value property.
///
/// Apple models emails, phones, and URLs as labelled multi-value properties — a
/// contact can carry several of each, and each carries a label. A bare `String`
/// cannot express that, which is why the read projection was lossy before
/// labelled values were introduced (3.1.0).
///
/// ## Example
/// ```swift
/// LabeledValue(label: "work", value: "john@example.com")
/// LabeledValue(value: "john@personal.example")   // unlabelled
/// ```
public struct LabeledValue: Codable, Sendable, Equatable {
    /// The Contacts label — `"home"`, `"work"`, or a raw key such as
    /// `"_$!<HomePage>!$_"` — or `nil` when the entry carries no label.
    public let label: String?

    /// The address, number, or URL itself.
    public let value: String

    /// Creates a labelled value.
    /// - Parameters:
    ///   - label: The Contacts label, or `nil` when unlabelled.
    ///   - value: The address, number, or URL.
    public init(label: String? = nil, value: String) {
        self.label = label
        self.value = value
    }
}

/// A contact from Apple Contacts.
///
/// ## Singular vs. plural fields
///
/// `email` and `phone` are **projections**, not storage: each returns the first
/// element of its collection, which is the same value they returned before the
/// collections existed. Nothing can set them independently of `emails` /
/// `phones`, so the two can never disagree.
///
/// A `nil` collection means the adapter did not project that property at all; an
/// empty collection means it projected and found none. Callers that need to tell
/// "no emails" from "not fetched" can rely on that distinction.
///
/// ## Example
/// ```swift
/// let contact = Contact(
///     id: "C123",
///     displayName: "John Doe",
///     email: "john@example.com",
///     phone: "+1-555-0100"
/// )
/// contact.emails   // [LabeledValue(label: nil, value: "john@example.com")]
/// contact.email    // "john@example.com"
/// ```
public struct Contact: Codable, Sendable, Equatable {
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

    /// Creates a new contact.
    ///
    /// `email` / `phone` are shorthands for a single unlabelled entry: passing
    /// `email:` is equivalent to passing `emails: [LabeledValue(value: …)]`. When
    /// both a singular and its plural are supplied the **plural wins**, because
    /// it is the richer form; the tool layer rejects that combination before it
    /// reaches here (see `ContactsHandlers`).
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

    // MARK: - Codable

    /// `email` and `phone` stay in the encoded form even though they are
    /// computed: they were part of the wire shape before the collections
    /// existed, and consumers of the four read tools still read them.
    private enum CodingKeys: String, CodingKey {
        case id, displayName, email, phone
        case givenName, familyName, organization, jobTitle, note
        case emails, phones, urls
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(givenName, forKey: .givenName)
        try container.encodeIfPresent(familyName, forKey: .familyName)
        try container.encodeIfPresent(organization, forKey: .organization)
        try container.encodeIfPresent(jobTitle, forKey: .jobTitle)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(emails, forKey: .emails)
        try container.encodeIfPresent(phones, forKey: .phones)
        try container.encodeIfPresent(urls, forKey: .urls)
    }

    /// Decodes a contact, accepting the pre-collections wire shape.
    ///
    /// JSON written before this change carries only `email` / `phone`; those are
    /// folded into single-element collections so the projections still resolve.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        givenName = try container.decodeIfPresent(String.self, forKey: .givenName)
        familyName = try container.decodeIfPresent(String.self, forKey: .familyName)
        organization = try container.decodeIfPresent(String.self, forKey: .organization)
        jobTitle = try container.decodeIfPresent(String.self, forKey: .jobTitle)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        urls = try container.decodeIfPresent([LabeledValue].self, forKey: .urls)

        let decodedEmails = try container.decodeIfPresent([LabeledValue].self, forKey: .emails)
        let legacyEmail = try container.decodeIfPresent(String.self, forKey: .email)
        emails = decodedEmails ?? legacyEmail.map { [LabeledValue(value: $0)] }

        let decodedPhones = try container.decodeIfPresent([LabeledValue].self, forKey: .phones)
        let legacyPhone = try container.decodeIfPresent(String.self, forKey: .phone)
        phones = decodedPhones ?? legacyPhone.map { [LabeledValue(value: $0)] }
    }
}
