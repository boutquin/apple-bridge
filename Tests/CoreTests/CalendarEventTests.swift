import Testing
import Foundation
@testable import Core

@Suite("CalendarEvent Tests")
struct CalendarEventTests {
    @Test func testCalendarEventRoundTrip() throws {
        let event = CalendarEvent(
            id: "E1",
            title: "Meeting",
            startDate: "2026-01-27T10:00:00Z",
            endDate: "2026-01-27T11:00:00Z",
            calendarId: "cal1",
            location: "Office",
            notes: "Bring laptop"
        )
        let json = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CalendarEvent.self, from: json)
        #expect(decoded.id == "E1")
        #expect(decoded.title == "Meeting")
        #expect(decoded.startDate == "2026-01-27T10:00:00Z")
        #expect(decoded.endDate == "2026-01-27T11:00:00Z")
        #expect(decoded.calendarId == "cal1")
        #expect(decoded.location == "Office")
        #expect(decoded.notes == "Bring laptop")
    }

    @Test func testCalendarEventWithNilOptionals() throws {
        let event = CalendarEvent(
            id: "E2",
            title: "Quick sync",
            startDate: "2026-01-27T14:00:00Z",
            endDate: "2026-01-27T14:30:00Z",
            calendarId: "cal1",
            location: nil,
            notes: nil
        )
        let json = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CalendarEvent.self, from: json)
        #expect(decoded.location == nil)
        #expect(decoded.notes == nil)
    }

    @Test func testCalendarEventPatchPartialFields() throws {
        let patch = CalendarEventPatch(
            title: "New Title",
            startDate: nil,
            endDate: nil,
            location: nil,
            notes: nil
        )
        let encoder = JSONEncoder()
        let json = try encoder.encode(patch)
        let str = String(data: json, encoding: .utf8)!

        // Only title should be present
        #expect(str.contains("\"title\":\"New Title\""))
    }

    @Test func testCalendarEventPatchAllFields() throws {
        let patch = CalendarEventPatch(
            title: "Updated Meeting",
            startDate: "2026-01-28T10:00:00Z",
            endDate: "2026-01-28T11:00:00Z",
            location: "Conference Room",
            notes: "Updated notes"
        )
        let json = try JSONEncoder().encode(patch)
        let decoded = try JSONDecoder().decode(CalendarEventPatch.self, from: json)
        #expect(decoded.title == "Updated Meeting")
        #expect(decoded.startDate == "2026-01-28T10:00:00Z")
        #expect(decoded.endDate == "2026-01-28T11:00:00Z")
        #expect(decoded.location == "Conference Room")
        #expect(decoded.notes == "Updated notes")
    }
}
