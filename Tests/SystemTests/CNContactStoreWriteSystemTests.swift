import Foundation
import Testing
import AppleBridgeContacts
import AppleBridgeCore

#if canImport(Contacts)
import Contacts
#endif

/// End-to-end round-trip tests for the `CNContactStore` write path —
/// `ContactsAdapter.createContact` / `updateContact` against the real address
/// book.
///
/// ## Why this suite exists
///
/// The MCP server wires `AppleScriptContactsAdapter` (see
/// `ContactsWriteSystemTests`), so `ContactsAdapter` was long a secondary
/// implementation whose writes nothing exercised for real. Since 3.2.0 it is
/// public API in the `AppleBridgeContacts` library, and a signed app that holds
/// its own Contacts grant uses exactly this path. These tests are what make it
/// supported rather than merely present.
///
/// ## Prerequisites
/// - `APPLE_BRIDGE_SYSTEM_TESTS=1`
/// - Contacts access granted to the test runner (attributed to the responsible
///   parent process — Claude, Terminal, or the IDE)
/// - Contacts.app does NOT need to be running: this path is in-process.
///
/// ## These tests write to the real address book
///
/// Every record is removed through `CNContactStore` in the same test, even
/// when an assertion fails, and every name carries a prefix plus a UUID so a
/// leak is findable by hand. Serialized: the tests share one address book.
@Suite(
    "CNContactStore Write System Tests",
    .serialized,
    .enabled(if: SystemTestHelper.systemTestsEnabled && SystemTestHelper.contactsAccess)
)
struct CNContactStoreWriteSystemTests {

    /// Prefix every test record carries; distinct from the AppleScript suite's
    /// so a leak names the path that leaked it.
    private static let namePrefix = "apple-bridge-cntest"

    private func uniqueName() -> String {
        "\(Self.namePrefix)-\(UUID().uuidString.prefix(8))"
    }

    #if canImport(Contacts)
    /// Deletes a test record through the store itself. Never throws: cleanup
    /// may run while an assertion failure is already propagating.
    private static func delete(id: String) {
        let store = CNContactStore()
        do {
            let contact = try store.unifiedContact(
                withIdentifier: id, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
            guard let mutable = contact.mutableCopy() as? CNMutableContact else { return }
            let request = CNSaveRequest()
            request.delete(mutable)
            try store.execute(request)
        } catch {
            FileHandle.standardError.write(
                Data("[cleanup] FAILED to delete CN test contact \(id): \(error)\n".utf8))
        }
    }

    /// The raw labels as the store holds them, bypassing the adapter's read
    /// projection — so the write path is judged on what it stored, not on what
    /// the same adapter reads back.
    private static func rawEmailLabels(id: String) throws -> [String?] {
        let contact = try CNContactStore().unifiedContact(
            withIdentifier: id, keysToFetch: [CNContactEmailAddressesKey as CNKeyDescriptor])
        return contact.emailAddresses.map(\.label)
    }

    /// Counts records whose organization equals `marker`, scanning the store
    /// directly (name predicates cannot see a nameless record).
    private static func countOrganization(_ marker: String) throws -> Int {
        var count = 0
        let request = CNContactFetchRequest(
            keysToFetch: [CNContactOrganizationNameKey as CNKeyDescriptor])
        try CNContactStore().enumerateContacts(with: request) { contact, _ in
            if contact.organizationName == marker { count += 1 }
        }
        return count
    }
    #endif

    @Test("create → get returns every field that was set")
    func createThenGetReturnsAllFields() async throws {
        #if canImport(Contacts)
        let adapter = ContactsAdapter()
        let given = uniqueName()

        let created = try await adapter.createContact(ContactData(
            id: "", displayName: "",
            givenName: given, familyName: "Lovelace",
            organization: "Analytical Engines", jobTitle: "Chief Mathematician",
            emails: [LabeledValue(label: "work", value: "ada@example.com")],
            phones: [LabeledValue(label: "mobile", value: "+1 555 0100")],
            urls: [LabeledValue(label: "homepage", value: "https://example.com")]
        ))
        defer { Self.delete(id: created.id) }

        #expect(!created.id.isEmpty, "create must return a store-assigned id")
        let fetched = try await adapter.fetchContact(id: created.id)
        #expect(fetched.givenName == given)
        #expect(fetched.familyName == "Lovelace")
        #expect(fetched.organization == "Analytical Engines")
        #expect(fetched.jobTitle == "Chief Mathematician")
        #expect(fetched.emails == [LabeledValue(label: "work", value: "ada@example.com")])
        #expect(fetched.phones == [LabeledValue(label: "mobile", value: "+1 555 0100")])
        #expect(fetched.urls == [LabeledValue(label: "homepage", value: "https://example.com")])
        #endif
    }

    /// A caller's `"work"` must land as Contacts' standard Work label, not a
    /// custom label spelled "work" — the difference is visible in Contacts.app
    /// and to every other app that reads the record.
    @Test("standard labels are stored as Contacts' standard constants")
    func standardLabelsAreStoredAsConstants() async throws {
        #if canImport(Contacts)
        let adapter = ContactsAdapter()
        let created = try await adapter.createContact(ContactData(
            id: "", displayName: "", givenName: uniqueName(),
            emails: [
                LabeledValue(label: "work", value: "w@example.com"),
                LabeledValue(label: "home", value: "h@example.com"),
                LabeledValue(label: "Conference", value: "c@example.com")
            ]
        ))
        defer { Self.delete(id: created.id) }

        let raw = try Self.rawEmailLabels(id: created.id)
        #expect(raw == [CNLabelWork, CNLabelHome, "Conference"],
                "standard labels must map to CN constants; custom labels pass through")
        #endif
    }

    @Test("update of one field leaves the others intact")
    func updateChangesOnlyTheNamedField() async throws {
        #if canImport(Contacts)
        let adapter = ContactsAdapter()
        let created = try await adapter.createContact(ContactData(
            id: "", displayName: "", givenName: uniqueName(),
            organization: "Analytical Engines", jobTitle: "Mathematician",
            emails: [LabeledValue(label: "work", value: "ada@example.com")]
        ))
        defer { Self.delete(id: created.id) }

        _ = try await adapter.updateContact(id: created.id,
            ContactData(id: created.id, displayName: "", jobTitle: "Chief Mathematician"))

        let fetched = try await adapter.fetchContact(id: created.id)
        #expect(fetched.jobTitle == "Chief Mathematician")
        #expect(fetched.organization == "Analytical Engines", "an absent field must not blank the stored one")
        #expect(fetched.email == "ada@example.com")
        #endif
    }

    @Test("update with an empty string clears just that field")
    func emptyStringClearsOneField() async throws {
        #if canImport(Contacts)
        let adapter = ContactsAdapter()
        let created = try await adapter.createContact(ContactData(
            id: "", displayName: "", givenName: uniqueName(),
            organization: "Analytical Engines", jobTitle: "Chief Mathematician"
        ))
        defer { Self.delete(id: created.id) }

        _ = try await adapter.updateContact(id: created.id,
            ContactData(id: created.id, displayName: "", jobTitle: ""))

        let fetched = try await adapter.fetchContact(id: created.id)
        #expect(fetched.jobTitle == nil, "an explicit empty string must clear the field")
        #expect(fetched.organization == "Analytical Engines", "clearing one field must not touch another")
        #endif
    }

    @Test("a supplied collection replaces; [] clears")
    func collectionsReplaceAndEmptyClears() async throws {
        #if canImport(Contacts)
        let adapter = ContactsAdapter()
        let created = try await adapter.createContact(ContactData(
            id: "", displayName: "", givenName: uniqueName(),
            emails: [LabeledValue(label: "work", value: "first@example.com")],
            phones: [LabeledValue(label: "mobile", value: "+1 555 0100")]
        ))
        defer { Self.delete(id: created.id) }

        // Adding means sending the existing entries too.
        let existing = try await adapter.fetchContact(id: created.id).emails ?? []
        _ = try await adapter.updateContact(id: created.id, ContactData(
            id: created.id, displayName: "",
            emails: existing + [LabeledValue(label: "home", value: "second@example.com")]))
        var fetched = try await adapter.fetchContact(id: created.id)
        #expect(fetched.emails?.map(\.value) == ["first@example.com", "second@example.com"])
        #expect(fetched.email == "first@example.com")
        #expect(fetched.phones?.count == 1, "an absent collection must be left alone")

        _ = try await adapter.updateContact(id: created.id,
            ContactData(id: created.id, displayName: "", phones: []))
        fetched = try await adapter.fetchContact(id: created.id)
        #expect(fetched.phones == [], "an empty array must clear the collection")
        #expect(fetched.emails?.count == 2)
        #endif
    }

    /// `note` needs Apple's restricted Contacts-notes entitlement, so this path
    /// neither writes nor reads it. Pinned so the limitation cannot turn into a
    /// crash (`CNPropertyNotFetchedException`) or a silent partial write unnoticed.
    @Test("note is not written, and reading back does not crash")
    func noteIsNotWritten() async throws {
        #if canImport(Contacts)
        let adapter = ContactsAdapter()
        let created = try await adapter.createContact(ContactData(
            id: "", displayName: "", givenName: uniqueName(), note: "not stored by this path"))
        defer { Self.delete(id: created.id) }

        #expect(created.note == nil, "note is not projected by the CNContactStore adapter")
        let fetched = try await adapter.fetchContact(id: created.id)
        #expect(fetched.note == nil)
        #endif
    }

    @Test("update on an unknown id is not-found")
    func updateUnknownIdIsNotFound() async throws {
        let adapter = ContactsAdapter()
        await #expect(throws: ValidationError.self) {
            _ = try await adapter.updateContact(
                id: "no-such-contact-\(UUID().uuidString)",
                ContactData(id: "", displayName: "", jobTitle: "Ghost"))
        }
    }

    @Test("a create with no name is rejected and leaves nothing behind")
    func rejectedCreateLeavesNothing() async throws {
        #if canImport(Contacts)
        let adapter = ContactsAdapter()
        let marker = uniqueName()
        #expect(try Self.countOrganization(marker) == 0)

        await #expect(throws: ValidationError.self) {
            _ = try await adapter.createContact(ContactData(
                id: "", displayName: "", organization: marker))
        }

        #expect(try Self.countOrganization(marker) == 0, "a rejected create must not persist a record")
        #endif
    }

    @Test("no test record survives the suite")
    func suiteLeavesNoRecordsBehind() async throws {
        let leaked = try await ContactsAdapter().fetchContacts(query: Self.namePrefix, limit: 100)
        #expect(leaked.isEmpty, "leaked test contacts: \(leaked.map(\.displayName))")
    }
}
