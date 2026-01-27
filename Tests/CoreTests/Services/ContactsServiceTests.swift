import Testing
import Foundation
@testable import Core
import TestUtilities

@Suite("ContactsService Protocol Tests")
struct ContactsServiceTests {

    // MARK: - Protocol Conformance Tests

    @Test func testMockContactsServiceConforms() async throws {
        let mock = MockContactsService()
        let contacts = try await mock.search(query: "test", limit: 10)
        #expect(contacts.isEmpty)
    }

    @Test func testMockContactsServiceIsSendable() {
        let mock = MockContactsService()
        Task { @Sendable in _ = mock }
    }

    // MARK: - Search Tests

    @Test func testSearchContactsWithStubData() async throws {
        let mock = MockContactsService()
        await mock.setStubContacts([
            makeTestContact(id: "C1", displayName: "John Doe"),
            makeTestContact(id: "C2", displayName: "Jane Smith")
        ])

        let contacts = try await mock.search(query: "John", limit: 10)
        #expect(contacts.count == 1)
        #expect(contacts[0].displayName == "John Doe")
    }

    @Test func testSearchContactsRespectsLimit() async throws {
        let mock = MockContactsService()
        await mock.setStubContacts([
            makeTestContact(id: "C1", displayName: "John A"),
            makeTestContact(id: "C2", displayName: "John B"),
            makeTestContact(id: "C3", displayName: "John C")
        ])

        let contacts = try await mock.search(query: "John", limit: 2)
        #expect(contacts.count == 2)
    }

    // MARK: - Get Contact Tests

    @Test func testGetContactById() async throws {
        let mock = MockContactsService()
        let testContact = makeTestContact(id: "C123", displayName: "Test Person")
        await mock.setStubContacts([testContact])

        let contact = try await mock.get(id: "C123")
        #expect(contact.id == "C123")
        #expect(contact.displayName == "Test Person")
    }

    @Test func testGetContactNotFoundThrows() async throws {
        let mock = MockContactsService()
        await mock.setStubContacts([])

        await #expect(throws: (any Error).self) {
            _ = try await mock.get(id: "nonexistent")
        }
    }

    // MARK: - Me Contact Tests

    @Test func testMeContactReturnsNilWhenNotSet() async throws {
        let mock = MockContactsService()

        let me = try await mock.me()
        #expect(me == nil)
    }

    @Test func testMeContactReturnsStubbed() async throws {
        let mock = MockContactsService()
        let meContact = makeTestContact(id: "ME", displayName: "User")
        await mock.setStubMeContact(meContact)

        let me = try await mock.me()
        #expect(me?.id == "ME")
    }

    // MARK: - Open Contact Tests

    @Test func testOpenContact() async throws {
        let mock = MockContactsService()
        let testContact = makeTestContact(id: "C1")
        await mock.setStubContacts([testContact])

        try await mock.open(id: "C1")
        // No throw = success
    }

    @Test func testOpenContactNotFoundThrows() async throws {
        let mock = MockContactsService()
        await mock.setStubContacts([])

        await #expect(throws: (any Error).self) {
            try await mock.open(id: "nonexistent")
        }
    }
}
