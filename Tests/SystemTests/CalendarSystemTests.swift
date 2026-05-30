import Foundation
import Testing
import Adapters
import Core

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
/// Gated on **full** calendar access (not just the system-tests env var):
/// every test here reads events, and the round-trip tests must delete what
/// they create. Under write-only ("Add events only") access reads return
/// nothing and a created event could not be cleaned up, so the suite skips
/// rather than leak. See `SystemTestHelper.calendarFullAccess`.
@Suite("Calendar System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled && SystemTestHelper.calendarFullAccess))
struct CalendarSystemTests {

    /// Verifies that the calendar service can list events without crashing.
    ///
    /// This is a smoke test that confirms:
    /// - EventKit permissions are working
    /// - The service initializes correctly
    /// - Basic query execution succeeds
    @Test("Real calendar access works")
    func testRealCalendarAccess() async throws {
        let adapter = EventKitAdapter()
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
        let adapter = EventKitAdapter()
        let service = EventKitCalendarService(adapter: adapter)
        // Search for a common term that might exist
        let events = try await service.searchEvents(query: "meeting", limit: 5, from: nil, to: nil, cursor: nil)

        // Verify valid response structure
        #expect(events.items.count >= 0)
        #expect(events.items.count <= 5)
    }

    // MARK: - Identifier Round-Trip (chore-calendar-event-identifier-roundtrip)

    /// ISO-8601 formatter matching the service's own format (fractional seconds).
    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Full create→get→update→list/search→delete round-trip on the user's
    /// default calendar (which is iCloud-backed in the production environment
    /// that surfaced the bug).
    ///
    /// Asserts every acceptance criterion of the chore: the id returned by
    /// `createEvent` resolves through `getEvent`, `updateEvent`, `listEvents`,
    /// and `searchEvents`, and `deleteEvent` removes it — all within one
    /// process session.
    @Test("create→get→update→list/search→delete round-trip resolves the returned id")
    func testIdentifierRoundTrip() async throws {
        let adapter = EventKitAdapter()
        let service = EventKitCalendarService(adapter: adapter)

        // Unique token so list/search cannot collide with pre-existing events.
        let token = "apple-bridge-roundtrip-\(UUID().uuidString)"
        let start = Date().addingTimeInterval(3600)          // +1h
        let end = start.addingTimeInterval(1800)             // +30m
        let window = (from: Self.iso(start.addingTimeInterval(-600)),
                      to: Self.iso(end.addingTimeInterval(600)))

        let id = try await service.createEvent(
            title: token,
            startDate: Self.iso(start),
            endDate: Self.iso(end),
            calendarId: nil,
            location: nil,
            notes: "round-trip integration test"
        )

        // Guarantee cleanup even if an assertion below fails.
        var deleted = false
        func cleanup() async { if !deleted { try? await service.deleteEvent(id: id) } }

        do {
            #expect(!id.isEmpty)

            // AC: create→get resolves the returned id.
            let fetched = try await service.getEvent(id: id)
            #expect(fetched.id == id)
            #expect(fetched.title == token)

            // AC: update resolves and mutates the just-created event.
            let newTitle = token + "-updated"
            let updated = try await service.updateEvent(
                id: id,
                patch: CalendarEventPatch(title: newTitle, startDate: nil, endDate: nil, location: nil, notes: nil)
            )
            #expect(updated.title == newTitle)

            // AC: list over the event's window includes it.
            let listed = try await service.listEvents(limit: 200, from: window.from, to: window.to, cursor: nil)
            #expect(listed.items.contains { $0.id == id })

            // AC: search by the unique token includes it.
            let found = try await service.searchEvents(query: newTitle, limit: 50, from: window.from, to: window.to, cursor: nil)
            #expect(found.items.contains { $0.id == id })

            // AC: delete removes the event; a subsequent get fails.
            try await service.deleteEvent(id: id)
            deleted = true
            await #expect(throws: ValidationError.self) {
                _ = try await service.getEvent(id: id)
            }
        } catch {
            await cleanup()
            throw error
        }
        await cleanup()
    }

    /// Negative paths: an unknown identifier never falsely resolves, and a
    /// double-delete surfaces not-found deterministically rather than crashing.
    @Test("Unknown id and double-delete surface not-found, not a crash")
    func testIdentifierNegativePaths() async throws {
        let adapter = EventKitAdapter()
        let service = EventKitCalendarService(adapter: adapter)

        // (1) A genuinely unknown id resolves to nothing.
        await #expect(throws: ValidationError.self) {
            _ = try await service.getEvent(id: "apple-bridge-nonexistent-\(UUID().uuidString)")
        }

        // (2) Deleting an already-deleted event is a deterministic not-found.
        let start = Date().addingTimeInterval(7200)
        let id = try await service.createEvent(
            title: "apple-bridge-doubledelete-\(UUID().uuidString)",
            startDate: Self.iso(start),
            endDate: Self.iso(start.addingTimeInterval(900)),
            calendarId: nil,
            location: nil,
            notes: nil
        )
        try await service.deleteEvent(id: id)
        await #expect(throws: ValidationError.self) {
            try await service.deleteEvent(id: id)
        }
    }
}
