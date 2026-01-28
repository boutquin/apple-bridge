import Foundation
import Testing
import Adapters

/// System tests for Calendar domain using real EventKit.
///
/// These tests verify that the calendar service works correctly with the
/// actual system calendar. They require EventKit permissions to be granted.
///
/// ## Prerequisites
/// - Calendar access must be granted to the test runner
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
///
/// ## What These Tests Verify
/// - Service can connect to EventKit without crashing
/// - Basic operations return valid data structures
/// - Error handling works for real-world scenarios
@Suite("Calendar System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct CalendarSystemTests {

    /// Verifies that the calendar service can list events without crashing.
    ///
    /// This is a smoke test that confirms:
    /// - EventKit permissions are working
    /// - The service initializes correctly
    /// - Basic query execution succeeds
    @Test("Real calendar access works")
    func testRealCalendarAccess() async throws {
        let adapter = RealEventKitAdapter()
        let service = EventKitCalendarService(adapter: adapter)
        let events = try await service.listEvents(limit: 1, from: nil, to: nil, cursor: nil)

        // Just verify no crash and valid response structure
        // We don't assert on content since the user's calendar may be empty
        #expect(events.items.count >= 0)
        #expect(events.items.count <= 1)
    }

    /// Verifies that the calendar service can search events.
    @Test("Real calendar search works")
    func testRealCalendarSearch() async throws {
        let adapter = RealEventKitAdapter()
        let service = EventKitCalendarService(adapter: adapter)
        // Search for a common term that might exist
        let events = try await service.searchEvents(query: "meeting", limit: 5, from: nil, to: nil, cursor: nil)

        // Verify valid response structure
        #expect(events.items.count >= 0)
        #expect(events.items.count <= 5)
    }
}
