import Testing
import Foundation
import Core
import Adapters
@testable import TestUtilities

/// Tests for `ContactsAdapterProtocol` and `ContactsFrameworkService`.
@Suite("Contacts Adapter Tests")
struct ContactsAdapterTests {

    // MARK: - Adapter Protocol Tests

    @Test("MockContactsAdapter conforms to protocol")
    func testMockContactsAdapterConforms() async throws {
        let adapter = MockContactsAdapter()
        #expect(adapter is any ContactsAdapterProtocol)
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
            CNContactData(id: "C1", displayName: "John Doe", email: "john@example.com", phone: nil),
            CNContactData(id: "C2", displayName: "Jane Smith", email: "jane@example.com", phone: nil)
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
            CNContactData(id: "C1", displayName: "John Doe", email: "johnny@example.com", phone: nil),
            CNContactData(id: "C2", displayName: "Jane Smith", email: "jane@example.com", phone: nil)
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
            CNContactData(id: "C1", displayName: "John Doe", email: nil, phone: "+1-555-0100"),
            CNContactData(id: "C2", displayName: "Jane Smith", email: nil, phone: "+1-555-0200")
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
            CNContactData(id: "C1", displayName: "Test Contact 1", email: nil, phone: nil),
            CNContactData(id: "C2", displayName: "Test Contact 2", email: nil, phone: nil),
            CNContactData(id: "C3", displayName: "Test Contact 3", email: nil, phone: nil)
        ])
        let service = ContactsFrameworkService(adapter: adapter)

        let results = try await service.search(query: "Test", limit: 2)
        #expect(results.count == 2)
    }

    @Test("ContactsFrameworkService search returns empty for no matches")
    func testContactsSearchReturnsEmptyForNoMatches() async throws {
        let adapter = MockContactsAdapter()
        await adapter.setStubContacts([
            CNContactData(id: "C1", displayName: "John Doe", email: nil, phone: nil)
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
            CNContactData(id: "C1", displayName: "John Doe", email: "john@example.com", phone: "+1-555-0100")
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
        await adapter.setStubMeContact(CNContactData(
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
            CNContactData(id: "C1", displayName: "John Doe", email: nil, phone: nil)
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
}
