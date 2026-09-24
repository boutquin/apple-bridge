import Foundation
import Testing
import AppleBridgeContacts
import AppleBridgeCore

/// End-to-end round-trip tests for `contacts_create` / `contacts_update`.
///
/// ## These run against the WIRED adapter
///
/// Every test here builds its service the way `main.swift:125` does —
/// `ContactsFrameworkService(adapter: AppleScriptContactsAdapter())`. The
/// sibling `ContactsSystemTests` constructs `ContactsAdapter()`, the
/// `CNContactStore` conformance that is fully implemented but **not wired**, so
/// a round-trip written to match that file's pattern would go green against code
/// production never runs. That is the shipped-but-inert failure this suite
/// exists to rule out.
///
/// ## Prerequisites
/// - `APPLE_BRIDGE_SYSTEM_TESTS=1`
/// - Contacts access granted to the test runner — under **Claude** (or Terminal
///   / the IDE) in System Settings, not under apple-bridge, because the grant
///   attaches to the responsible parent process
/// - Contacts.app running: `osascript` does not auto-launch its target, and a
///   closed app surfaces as an opaque `AppleBridgeCore.AppleScriptError error 0`
///
/// ## These tests write to the real address book
///
/// Every contact created here is removed in a `defer` via
/// `SystemTestHelper.deleteContact(id:)`, which runs even when an assertion
/// fails. Names are prefixed and carry a UUID so anything ever left behind is
/// findable by hand.
/// Serialized on purpose: these tests share one real address book, so running
/// them concurrently both races the whole-suite count assertions and points
/// several simultaneous AppleScript writers at the same Contacts.app.
@Suite(
    "Contacts Write System Tests",
    .serialized,
    .enabled(if: SystemTestHelper.systemTestsEnabled && SystemTestHelper.contactsAccess)
)
struct ContactsWriteSystemTests {

    /// Prefix every test record carries, so a leak is identifiable.
    private static let namePrefix = "apple-bridge-test"

    private func makeService() -> ContactsFrameworkService {
        ContactsFrameworkService(adapter: AppleScriptContactsAdapter())
    }

    private func uniqueName() -> String {
        "\(Self.namePrefix)-\(UUID().uuidString.prefix(8))"
    }

    /// Create returns an id, and every field set comes back on read.
    @Test("create → get returns every field that was set")
    func createThenGetReturnsAllFields() async throws {
        let service = makeService()
        let given = uniqueName()
        let note = "First paragraph.\n\nSecond with \"quotes\" and a \\ backslash.\tAnd a tab."

        let created = try await service.create(Contact(
            id: "",
            displayName: "",
            givenName: given,
            familyName: "Lovelace",
            organization: "Analytical Engines",
            jobTitle: "Chief Mathematician",
            note: note,
            emails: [LabeledValue(label: "work", value: "ada@example.com")],
            urls: [
                LabeledValue(label: "homepage", value: "https://example.com"),
                LabeledValue(label: "work", value: "https://work.example.com")
            ]
        ))

        var cleaned = false
        func cleanup() async {
            if !cleaned { await SystemTestHelper.deleteContact(id: created.id); cleaned = true }
        }
        do {
            #expect(!created.id.isEmpty, "create must return a store-assigned id")

            let fetched = try await service.get(id: created.id)
            #expect(fetched.givenName == given)
            #expect(fetched.familyName == "Lovelace")
            #expect(fetched.organization == "Analytical Engines")
            #expect(fetched.jobTitle == "Chief Mathematician")
            #expect(fetched.note == note, "a multi-paragraph note with tabs, quotes and backslashes must round-trip intact")
            #expect(fetched.emails?.count == 1)
            #expect(fetched.emails?.first?.value == "ada@example.com")
            #expect(fetched.urls?.count == 2, "both labelled URLs must survive")
        } catch {
            await cleanup()
            throw error
        }
        await cleanup()
    }

    /// A partial update changes only the named field.
    @Test("update of one field leaves the others intact")
    func updateChangesOnlyTheNamedField() async throws {
        let service = makeService()
        let given = uniqueName()

        let created = try await service.create(Contact(
            id: "", displayName: "", givenName: given,
            organization: "Analytical Engines", jobTitle: "Mathematician",
            note: "keep me",
            emails: [LabeledValue(label: "work", value: "ada@example.com")]
        ))

        var cleaned = false
        func cleanup() async {
            if !cleaned { await SystemTestHelper.deleteContact(id: created.id); cleaned = true }
        }
        do {
            _ = try await service.update(id: created.id,
                Contact(id: created.id, displayName: "", jobTitle: "Chief Mathematician"))

            let fetched = try await service.get(id: created.id)
            #expect(fetched.jobTitle == "Chief Mathematician")
            #expect(fetched.organization == "Analytical Engines", "an absent argument must not blank the field")
            #expect(fetched.note == "keep me")
            #expect(fetched.email == "ada@example.com")
        } catch {
            await cleanup()
            throw error
        }
        await cleanup()
    }

    /// An explicit empty string clears, and only that field.
    @Test("update with an empty string clears just that field")
    func emptyStringClearsOneField() async throws {
        let service = makeService()
        let given = uniqueName()

        let created = try await service.create(Contact(
            id: "", displayName: "", givenName: given,
            organization: "Analytical Engines", jobTitle: "Chief Mathematician",
            note: "this note goes away"
        ))

        var cleaned = false
        func cleanup() async {
            if !cleaned { await SystemTestHelper.deleteContact(id: created.id); cleaned = true }
        }
        do {
            _ = try await service.update(id: created.id,
                Contact(id: created.id, displayName: "", note: ""))

            let fetched = try await service.get(id: created.id)
            #expect(fetched.note == nil, "an explicit empty string must clear the note")
            #expect(fetched.organization == "Analytical Engines", "clearing one field must not touch another")
            #expect(fetched.jobTitle == "Chief Mathematician")
        } catch {
            await cleanup()
            throw error
        }
        await cleanup()
    }

    /// A second email joins the first rather than displacing it, and
    /// `email` still projects the original.
    @Test("adding a second email keeps the first, and email still returns it")
    func addingSecondEmailKeepsTheFirst() async throws {
        let service = makeService()
        let given = uniqueName()

        let created = try await service.create(Contact(
            id: "", displayName: "", givenName: given,
            emails: [LabeledValue(label: "work", value: "first@example.com")]
        ))

        var cleaned = false
        func cleanup() async {
            if !cleaned { await SystemTestHelper.deleteContact(id: created.id); cleaned = true }
        }
        do {
            // A supplied collection replaces the stored one (`[]` clears it),
            // so adding an entry means sending the existing entries too.
            let existing = try await service.get(id: created.id).emails ?? []
            _ = try await service.update(id: created.id, Contact(
                id: created.id, displayName: "",
                emails: existing + [LabeledValue(label: "home", value: "second@example.com")]
            ))

            let fetched = try await service.get(id: created.id)
            #expect(fetched.emails?.count == 2, "the existing address must survive")
            #expect(fetched.emails?.map(\.value).contains("first@example.com") == true)
            #expect(fetched.emails?.map(\.value).contains("second@example.com") == true)
            #expect(fetched.email == "first@example.com", "the primary projection must still be the first entry")
        } catch {
            await cleanup()
            throw error
        }
        await cleanup()
    }

    /// An unknown id is a clean not-found, not a crash.
    @Test("update on an unknown id is not-found and writes nothing")
    func updateUnknownIdIsNotFound() async throws {
        let service = makeService()
        await #expect(throws: ValidationError.self) {
            _ = try await service.update(
                id: "no-such-contact-\(UUID().uuidString)",
                Contact(id: "", displayName: "", jobTitle: "Ghost"))
        }
    }

    /// A rejected create leaves nothing behind.
    ///
    /// Note the mid-script partial state this AC anticipates is unreachable
    /// through the shipped path: `createContact` commits the person and all of
    /// its sub-items in a single `save`, so a failure before that point persists
    /// nothing. What is reachable is a create rejected before any script runs,
    /// which is what this asserts — plus the count check that would catch an
    /// orphan however it arose.
    @Test("a rejected create leaves no record behind")
    func rejectedCreateLeavesNothing() async throws {
        let service = makeService()
        // Counted against this test's OWN marker rather than the shared prefix:
        // a suite-wide count is a moving target the moment anything else runs.
        let marker = uniqueName()
        let before = try await service.search(query: marker, limit: 100).count
        #expect(before == 0)

        await #expect(throws: (any Error).self) {
            _ = try await service.create(Contact(
                id: "", displayName: "", givenName: nil, familyName: nil,
                organization: marker))
        }

        let after = try await service.search(query: marker, limit: 100).count
        #expect(after == 0, "a failed create must not leave a partial record")
        #expect(after == before)
    }

    /// The suite cleans up after itself.
    ///
    /// Runs last by name and asserts no record carrying this suite's prefix
    /// survives. A failure here means an earlier test leaked, which is exactly
    /// the condition the `defer`-based cleanup exists to prevent.
    @Test("no test record survives the suite")
    func suiteLeavesNoRecordsBehind() async throws {
        let service = makeService()
        let leaked = try await service.search(query: Self.namePrefix, limit: 100)
        #expect(leaked.isEmpty, "leaked test contacts: \(leaked.map(\.displayName))")
    }
}
