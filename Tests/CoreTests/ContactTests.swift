import Testing
import Foundation
@testable import AppleBridgeCore

@Suite("Contact Tests")
struct ContactTests {
    @Test func testContactRoundTrip() throws {
        let contact = Contact(
            id: "C1",
            displayName: "John Doe",
            email: "john@example.com",
            phone: "+1234567890"
        )
        let json = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(Contact.self, from: json)
        #expect(decoded.id == "C1")
        #expect(decoded.displayName == "John Doe")
        #expect(decoded.email == "john@example.com")
        #expect(decoded.phone == "+1234567890")
    }

    @Test func testContactWithNilOptionals() throws {
        let contact = Contact(
            id: "C2",
            displayName: "Jane Smith",
            email: nil,
            phone: nil
        )
        let json = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(Contact.self, from: json)
        #expect(decoded.email == nil)
        #expect(decoded.phone == nil)
    }

    @Test func testContactEquality() {
        let contact1 = Contact(id: "C1", displayName: "John", email: nil, phone: nil)
        let contact2 = Contact(id: "C1", displayName: "John", email: nil, phone: nil)
        #expect(contact1 == contact2)
    }

    // MARK: - Widened DTO (labelled multi-values, job title, note)

    @Test("New fields round-trip through JSON")
    func widenedFieldsRoundTrip() throws {
        let contact = Contact(
            id: "C3",
            displayName: "Ada Lovelace",
            givenName: "Ada",
            familyName: "Lovelace",
            organization: "Analytical Engines Ltd",
            jobTitle: "Chief Mathematician",
            note: "Met at the\tsymposium.\n\nSecond paragraph with \"quotes\" and a \\ backslash.",
            emails: [LabeledValue(label: "work", value: "ada@example.com")],
            phones: [LabeledValue(label: "home", value: "+1-555-0100")],
            urls: [
                LabeledValue(label: "homepage", value: "https://example.com"),
                LabeledValue(label: "work", value: "https://work.example.com")
            ]
        )

        let decoded = try JSONDecoder().decode(Contact.self, from: JSONEncoder().encode(contact))

        #expect(decoded.givenName == "Ada")
        #expect(decoded.familyName == "Lovelace")
        #expect(decoded.organization == "Analytical Engines Ltd")
        #expect(decoded.jobTitle == "Chief Mathematician")
        #expect(decoded.note == contact.note, "a multi-paragraph note with tabs, newlines, quotes and backslashes must survive intact")
        #expect(decoded.urls?.count == 2)
        #expect(decoded.urls?.first?.label == "homepage")
        #expect(decoded == contact)
    }

    /// `email` is a projection of `emails`, never an independent store.
    @Test("email projects the first of emails, and survives a second being added")
    func emailProjectsFirstEntry() {
        let one = Contact(id: "C4", displayName: "A", email: "first@example.com")
        #expect(one.email == "first@example.com")
        #expect(one.emails?.count == 1)
        #expect(one.emails?.first?.label == nil, "the singular shorthand creates an unlabelled entry")

        let two = Contact(
            id: "C4",
            displayName: "A",
            emails: [
                LabeledValue(label: "work", value: "first@example.com"),
                LabeledValue(label: "home", value: "second@example.com")
            ]
        )
        #expect(two.email == "first@example.com", "adding a second email must not change what `email` returns")
        #expect(two.emails?.count == 2)
    }

    /// The plural is the richer form, so it wins; the tool layer rejects the
    /// combination before it gets here.
    @Test("A supplied plural wins over its singular")
    func pluralWinsOverSingular() {
        let contact = Contact(
            id: "C5",
            displayName: "A",
            email: "ignored@example.com",
            emails: [LabeledValue(label: "work", value: "kept@example.com")]
        )
        #expect(contact.email == "kept@example.com")
        #expect(contact.emails?.count == 1)
    }

    /// `nil` means "not projected"; `[]` means "projected, none found".
    @Test("Empty and absent collections are distinguishable")
    func emptyAndAbsentDiffer() throws {
        let notProjected = Contact(id: "C6", displayName: "A")
        #expect(notProjected.emails == nil)
        #expect(notProjected.email == nil)

        let projectedEmpty = Contact(id: "C7", displayName: "A", emails: [])
        #expect(projectedEmpty.emails == [])
        #expect(projectedEmpty.email == nil)

        let decoded = try JSONDecoder().decode(Contact.self, from: JSONEncoder().encode(projectedEmpty))
        #expect(decoded.emails == [], "an empty collection must not decode back as nil")
    }

    /// JSON written before the collections existed still decodes.
    @Test("Legacy singular-only JSON folds into single-element collections")
    func legacyJSONDecodes() throws {
        let legacy = #"{"id":"C8","displayName":"Old Record","email":"old@example.com","phone":"+1-555-0199"}"#
        let decoded = try JSONDecoder().decode(Contact.self, from: Data(legacy.utf8))

        #expect(decoded.email == "old@example.com")
        #expect(decoded.phone == "+1-555-0199")
        #expect(decoded.emails?.count == 1)
        #expect(decoded.emails?.first?.value == "old@example.com")
        #expect(decoded.urls == nil)
    }

    /// The wire shape the four read tools already publish must not change.
    @Test("Encoded JSON still carries the singular email and phone keys")
    func encodedShapeKeepsSingularKeys() throws {
        let contact = Contact(id: "C9", displayName: "A", email: "a@example.com", phone: "+1")
        let object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(contact)
        ) as? [String: Any]

        #expect(object?["email"] as? String == "a@example.com")
        #expect(object?["phone"] as? String == "+1")
        #expect(object?["emails"] != nil)
    }

}
