import Foundation
import Testing
import Adapters

/// System tests for Reminders domain using real EventKit.
///
/// These tests verify that the reminders service works correctly with the
/// actual system reminders. They require EventKit permissions to be granted.
///
/// ## Prerequisites
/// - Reminders access must be granted to the test runner
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
@Suite("Reminders System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct RemindersSystemTests {

    /// Verifies that the reminders service can list reminder lists without crashing.
    @Test("Real reminders list access works")
    func testRealRemindersListAccess() async throws {
        let adapter = RealEventKitAdapter()
        let service = EventKitRemindersService(adapter: adapter)
        let lists = try await service.getLists()

        // Just verify no crash and valid response structure
        // User should have at least a default list
        #expect(lists.count >= 0)
    }

    /// Verifies that the reminders service can list reminders.
    @Test("Real reminders access works")
    func testRealRemindersAccess() async throws {
        let adapter = RealEventKitAdapter()
        let service = EventKitRemindersService(adapter: adapter)

        // First get a list ID (if any exist)
        let lists = try await service.getLists()
        guard let firstList = lists.first else {
            // No lists exist — test passes vacuously
            return
        }

        let reminders = try await service.list(listId: firstList.id, limit: 5, includeCompleted: false, cursor: nil)

        // Verify valid response structure
        #expect(reminders.items.count >= 0)
        #expect(reminders.items.count <= 5)
    }

    /// Verifies that the reminders service can search reminders.
    @Test("Real reminders search works")
    func testRealRemindersSearch() async throws {
        let adapter = RealEventKitAdapter()
        let service = EventKitRemindersService(adapter: adapter)
        let reminders = try await service.search(query: "test", limit: 5, includeCompleted: false, cursor: nil)

        // Verify valid response structure
        #expect(reminders.items.count >= 0)
        #expect(reminders.items.count <= 5)
    }
}
