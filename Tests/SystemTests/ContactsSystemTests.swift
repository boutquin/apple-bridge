import Foundation
import Testing
import Adapters

/// System tests for Contacts domain using real Contacts framework.
///
/// These tests verify that the contacts service works correctly with the
/// actual system Contacts database. They require Contacts permission.
///
/// ## Prerequisites
/// - Contacts access must be granted to the test runner
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
@Suite("Contacts System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct ContactsSystemTests {

    /// Verifies that the contacts service can search without crashing.
    @Test("Real contacts search works")
    func testRealContactsSearch() async throws {
        let adapter = ContactsAdapter()
        let service = ContactsFrameworkService(adapter: adapter)
        let contacts = try await service.search(query: "", limit: 5)

        // Just verify no crash and valid response structure
        #expect(contacts.count >= 0)
        #expect(contacts.count <= 5)
    }

    /// Verifies that the contacts service can search by name.
    @Test("Real contacts name search works")
    func testRealContactsNameSearch() async throws {
        let adapter = ContactsAdapter()
        let service = ContactsFrameworkService(adapter: adapter)
        // Search for a common name that might exist
        let contacts = try await service.search(query: "John", limit: 5)

        // Verify valid response structure
        #expect(contacts.count >= 0)
        #expect(contacts.count <= 5)
    }

    /// Verifies that the contacts service handles "me" card.
    @Test("Real contacts me card works")
    func testRealContactsMeCard() async throws {
        let adapter = ContactsAdapter()
        let service = ContactsFrameworkService(adapter: adapter)

        // me() returns nil on macOS (no CNContactStore.fetchMeCard())
        // This test verifies the method doesn't crash
        _ = try await service.me()

        // Just verify no crash — the result may be nil
    }
}
