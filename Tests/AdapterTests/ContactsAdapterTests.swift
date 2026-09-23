import Testing
import Foundation
import Core
@testable import Adapters
@testable import TestUtilities

/// Tests for `ContactsAdapterProtocol` and `ContactsFrameworkService`.
@Suite("Contacts Adapter Tests")
struct ContactsAdapterTests {

    // MARK: - Adapter Protocol Tests

    @Test("MockContactsAdapter conforms to protocol")
    func testMockContactsAdapterConforms() async throws {
        let adapter = MockContactsAdapter()
        let value: any Sendable = adapter
        #expect(value is any ContactsAdapterProtocol)
    }

    @Test("MockContactsAdapter is Sendable")
    func testMockContactsAdapterIsSendable() {
        let adapter = MockContactsAdapter()
        Task { @Sendable in _ = adapter }
    }

    // MARK: - Search Tests

    @Test("ContactsFrameworkService search returns matching contacts")
    func testContactsSearchReturnsMatches() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([
            ContactData(id: "C1", displayName: "John Doe", email: "john@example.com", phone: nil),
            ContactData(id: "C2", displayName: "Jane Smith", email: "jane@example.com", phone: nil)
        ])
        let service = ContactsFrameworkService(adapter: adapter)

        let results = try await service.search(query: "John", limit: 10)
        #expect(results.count == 1)
        #expect(results[0].displayName == "John Doe")
    }

    @Test("ContactsFrameworkService search filters by email")
    func testContactsSearchFiltersByEmail() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([
            ContactData(id: "C1", displayName: "John Doe", email: "johnny@example.com", phone: nil),
            ContactData(id: "C2", displayName: "Jane Smith", email: "jane@example.com", phone: nil)
        ])
        let service = ContactsFrameworkService(adapter: adapter)

        let results = try await service.search(query: "johnny", limit: 10)
        #expect(results.count == 1)
        #expect(results[0].id == "C1")
    }

    @Test("ContactsFrameworkService search filters by phone")
    func testContactsSearchFiltersByPhone() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([
            ContactData(id: "C1", displayName: "John Doe", email: nil, phone: "+1-555-0100"),
            ContactData(id: "C2", displayName: "Jane Smith", email: nil, phone: "+1-555-0200")
        ])
        let service = ContactsFrameworkService(adapter: adapter)

        let results = try await service.search(query: "555-0100", limit: 10)
        #expect(results.count == 1)
        #expect(results[0].id == "C1")
    }

    @Test("ContactsFrameworkService search respects limit")
    func testContactsSearchRespectsLimit() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([
            ContactData(id: "C1", displayName: "Test Contact 1", email: nil, phone: nil),
            ContactData(id: "C2", displayName: "Test Contact 2", email: nil, phone: nil),
            ContactData(id: "C3", displayName: "Test Contact 3", email: nil, phone: nil)
        ])
        let service = ContactsFrameworkService(adapter: adapter)

        let results = try await service.search(query: "Test", limit: 2)
        #expect(results.count == 2)
    }

    @Test("ContactsFrameworkService search returns empty for no matches")
    func testContactsSearchReturnsEmptyForNoMatches() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([
            ContactData(id: "C1", displayName: "John Doe", email: nil, phone: nil)
        ])
        let service = ContactsFrameworkService(adapter: adapter)

        let results = try await service.search(query: "xyz", limit: 10)
        #expect(results.isEmpty)
    }

    // MARK: - Get Tests

    @Test("ContactsFrameworkService get returns contact by ID")
    func testContactsGetReturnsContactById() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([
            ContactData(id: "C1", displayName: "John Doe", email: "john@example.com", phone: "+1-555-0100")
        ])
        let service = ContactsFrameworkService(adapter: adapter)

        let contact = try await service.get(id: "C1")
        #expect(contact.id == "C1")
        #expect(contact.displayName == "John Doe")
        #expect(contact.email == "john@example.com")
        #expect(contact.phone == "+1-555-0100")
    }

    @Test("ContactsFrameworkService get throws notFound for invalid ID")
    func testContactsGetThrowsNotFoundForInvalidId() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([])
        let service = ContactsFrameworkService(adapter: adapter)

        await #expect(throws: ValidationError.self) {
            _ = try await service.get(id: "nonexistent")
        }
    }

    // MARK: - Me Tests

    @Test("ContactsFrameworkService me returns user's contact card")
    func testContactsMeReturnsUsersCard() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubMeContact(ContactData(
            id: "ME",
            displayName: "Pierre Boutquin",
            email: "pierre@example.com",
            phone: nil
        ))
        let service = ContactsFrameworkService(adapter: adapter)

        let me = try await service.me()
        #expect(me?.displayName == "Pierre Boutquin")
        #expect(me?.id == "ME")
    }

    @Test("ContactsFrameworkService me returns nil when not configured")
    func testContactsMeReturnsNilWhenNotConfigured() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubMeContact(nil)
        let service = ContactsFrameworkService(adapter: adapter)

        let me = try await service.me()
        #expect(me == nil)
    }

    // MARK: - Open Tests

    @Test("ContactsFrameworkService open succeeds for valid ID")
    func testContactsOpenSucceedsForValidId() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([
            ContactData(id: "C1", displayName: "John Doe", email: nil, phone: nil)
        ])
        let service = ContactsFrameworkService(adapter: adapter)

        // Should not throw
        try await service.open(id: "C1")

        // Verify it was tracked
        let openedIds = await adapter.getOpenedContactIds()
        #expect(openedIds.contains("C1"))
    }

    @Test("ContactsFrameworkService open throws notFound for invalid ID")
    func testContactsOpenThrowsNotFoundForInvalidId() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([])
        let service = ContactsFrameworkService(adapter: adapter)

        await #expect(throws: ValidationError.self) {
            try await service.open(id: "nonexistent")
        }
    }

    // MARK: - Error Handling Tests

    @Test("ContactsFrameworkService propagates permission error")
    func testContactsServicePropagatesPermissionError() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setError(PermissionError.contactsDenied)
        let service = ContactsFrameworkService(adapter: adapter)

        await #expect(throws: PermissionError.self) {
            _ = try await service.search(query: "test", limit: 10)
        }
    }

    // MARK: - Label normalization

    @Test("Apple's raw label encoding is unwrapped for callers")
    func normalizesAppleLabelKeys() {
        #expect(AppleScriptContactsAdapter.normalizeLabel("_$!<Home>!$_") == "home")
        #expect(AppleScriptContactsAdapter.normalizeLabel("_$!<Work>!$_") == "work")
        #expect(AppleScriptContactsAdapter.normalizeLabel("_$!<HomePage>!$_") == "homepage")
    }

    @Test("Custom and empty labels survive normalization")
    func leavesCustomLabelsAlone() {
        #expect(AppleScriptContactsAdapter.normalizeLabel("cottage") == "cottage")
        #expect(AppleScriptContactsAdapter.normalizeLabel("") == nil)
        #expect(AppleScriptContactsAdapter.normalizeLabel("_$!<>!$_") == nil)
    }

    // MARK: - Write script building

    /// The injection case: a note carrying a double quote and a
    /// backslash must not terminate the AppleScript string or inject script.
    @Test("A note with quotes and backslashes is escaped, not injected")
    func escapesQuotesAndBackslashesInNote() {
        let hostile = #"He said "hello" \ then left; " & (do shell script "echo pwned") & ""#
        let data = ContactData(id: "ignored", displayName: "Ada", givenName: "Ada", note: hostile)
        let properties = AppleScriptContactsAdapter.personProperties(from: data, includeNameFallback: true)
        let note = properties.first { $0.hasPrefix("note:") }

        #expect(note != nil)
        // Every quote in the payload must be backslash-escaped, so the only
        // unescaped quotes are the two the property itself is wrapped in.
        let body = note!.dropFirst("note:".count)
        var unescaped = 0
        var previous: Character?
        for character in body {
            if character == "\"" && previous != "\\" { unescaped += 1 }
            previous = character
        }
        #expect(unescaped == 2, "found \(unescaped) unescaped quotes — the payload broke out of its string")
        #expect(note!.contains(#"\\"#), "the literal backslash must be doubled")
    }

    @Test("Escaping doubles backslashes and escapes quotes")
    func escapeStaticHandlesBothCharacters() {
        #expect(AppleScriptContactsAdapter.escapeStatic(#"a"b"#) == #"a\"b"#)
        #expect(AppleScriptContactsAdapter.escapeStatic(#"a\b"#) == #"a\\b"#)
        #expect(AppleScriptContactsAdapter.escapeStatic("plain") == "plain")
    }

    @Test("Only supplied fields reach the person properties")
    func absentFieldsAreOmitted() {
        let data = ContactData(id: "x", displayName: "Ada", givenName: "Ada", organization: "Analytical")
        let properties = AppleScriptContactsAdapter.personProperties(from: data, includeNameFallback: true)

        #expect(properties.contains { $0.hasPrefix("first name:") })
        #expect(properties.contains { $0.hasPrefix("organization:") })
        #expect(!properties.contains { $0.hasPrefix("job title:") }, "an absent field must not appear at all")
        #expect(!properties.contains { $0.hasPrefix("note:") })
    }

    /// Contacts derives `name`, so a display-name-only create becomes a first name.
    @Test("A display-name-only create falls back to first name")
    func displayNameFallsBackToFirstName() {
        let data = ContactData(id: "x", displayName: "Prince")
        let properties = AppleScriptContactsAdapter.personProperties(from: data, includeNameFallback: true)
        #expect(properties.first == #"first name:"Prince""#)
    }

    @Test("A labelled sub-item carries both label and value; an unlabelled one omits the label")
    func subItemBuilding() {
        let labelled = AppleScriptContactsAdapter.makeSubItem(
            element: "email", plural: "emails",
            entry: LabeledValue(label: "work", value: "a@example.com"), personVar: "p")
        #expect(labelled.contains(#"value:"a@example.com""#))
        #expect(labelled.contains(#"label:"work""#))
        #expect(labelled.hasPrefix("make new email at end of emails of p"))

        let bare = AppleScriptContactsAdapter.makeSubItem(
            element: "url", plural: "urls",
            entry: LabeledValue(value: "https://example.com"), personVar: "p")
        #expect(!bare.contains("label:"))
    }

    // MARK: - Write semantics via the mock

    @Test("Create records the call and returns a store-assigned id")
    func createReturnsAssignedId() async throws {
        let adapter = MockContactsAdapter()
        let created = try await adapter.createContact(
            ContactData(id: "ignored", displayName: "", givenName: "Ada", familyName: "Lovelace",
                        emails: [LabeledValue(label: "work", value: "ada@example.com")]))

        #expect(created.id != "ignored", "the store assigns the id; the supplied one is ignored")
        #expect(created.displayName == "Ada Lovelace")
        #expect(created.emails?.count == 1)
        #expect(await adapter.createdContacts.count == 1)
    }

    @Test("Create without any name field is rejected")
    func createRequiresAName() async throws {
        let adapter = MockContactsAdapter()
        await #expect(throws: ValidationError.self) {
            _ = try await adapter.createContact(ContactData(id: "x", displayName: ""))
        }
    }

    @Test("Update leaves absent fields alone and replaces supplied ones")
    func updateHonoursAbsentVsSupplied() async throws {
        let adapter = MockContactsAdapter()
        let created = try await adapter.createContact(
            ContactData(id: "x", displayName: "", givenName: "Ada",
                        organization: "Analytical", note: "keep me",
                        emails: [LabeledValue(value: "ada@example.com")]))

        let updated = try await adapter.updateContact(id: created.id,
            ContactData(id: created.id, displayName: "", jobTitle: "Chief Mathematician"))

        #expect(updated.jobTitle == "Chief Mathematician")
        #expect(updated.organization == "Analytical", "an absent field must survive the update")
        #expect(updated.note == "keep me")
        #expect(updated.emails?.count == 1)
    }

    @Test("Update on an unknown id is not found, and writes nothing")
    func updateUnknownIdThrows() async throws {
        let adapter = MockContactsAdapter()
        await #expect(throws: ValidationError.self) {
            _ = try await adapter.updateContact(id: "nope", ContactData(id: "nope", displayName: "", jobTitle: "X"))
        }
    }
}
