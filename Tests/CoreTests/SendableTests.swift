import Testing
import Foundation
@testable import Core

/// Tests that verify all domain models conform to Sendable.
/// These are compile-time checks that ensure models can be safely
/// passed across actor boundaries in Swift 6 concurrency.
@Suite("Sendable Conformance Tests")
struct SendableTests {

    // MARK: - Model Sendable Tests

    @Test func testCalendarEventIsSendable() {
        let event = CalendarEvent(
            id: "E1",
            title: "Test",
            startDate: "2026-01-27T10:00:00Z",
            endDate: "2026-01-27T11:00:00Z",
            calendarId: "cal-1"
        )
        Task { @Sendable in
            _ = event
        }
    }

    @Test func testCalendarEventPatchIsSendable() {
        let patch = CalendarEventPatch(title: "New Title")
        Task { @Sendable in
            _ = patch
        }
    }

    @Test func testReminderIsSendable() {
        let reminder = Reminder(
            id: "R1",
            title: "Test",
            isCompleted: false,
            listId: "list-1"
        )
        Task { @Sendable in
            _ = reminder
        }
    }

    @Test func testReminderListIsSendable() {
        let list = ReminderList(id: "L1", name: "Test")
        Task { @Sendable in
            _ = list
        }
    }

    @Test func testReminderPatchIsSendable() {
        let patch = ReminderPatch(title: "Updated")
        Task { @Sendable in
            _ = patch
        }
    }

    @Test func testContactIsSendable() {
        let contact = Contact(id: "C1", displayName: "Test")
        Task { @Sendable in
            _ = contact
        }
    }

    @Test func testNoteIsSendable() {
        let note = Note(id: "N1", modifiedAt: "2026-01-27T10:00:00Z")
        Task { @Sendable in
            _ = note
        }
    }

    @Test func testMessageIsSendable() {
        let message = Message(
            id: "M1",
            chatId: "chat-1",
            sender: "+1234567890",
            date: "2026-01-27T10:00:00Z",
            isUnread: false
        )
        Task { @Sendable in
            _ = message
        }
    }

    @Test func testEmailIsSendable() {
        let email = Email(
            id: "E1",
            subject: "Test",
            from: "sender@example.com",
            to: ["recipient@example.com"],
            date: "2026-01-27T10:00:00Z",
            isUnread: false
        )
        Task { @Sendable in
            _ = email
        }
    }

    @Test func testLocationIsSendable() {
        let location = Location(name: "Test Location")
        Task { @Sendable in
            _ = location
        }
    }

    @Test func testPageIsSendable() {
        let page = Page(items: ["a", "b"], nextCursor: nil, hasMore: false)
        Task { @Sendable in
            _ = page
        }
    }

    @Test func testCursorIsSendable() {
        let cursor = Cursor(lastId: "item-1", ts: 1706400000)
        Task { @Sendable in
            _ = cursor
        }
    }

    // MARK: - Collections of Models

    @Test func testArrayOfEventsIsSendable() {
        let events = [
            CalendarEvent(id: "E1", title: "Event 1", startDate: "2026-01-27T10:00:00Z", endDate: "2026-01-27T11:00:00Z", calendarId: "cal-1"),
            CalendarEvent(id: "E2", title: "Event 2", startDate: "2026-01-27T12:00:00Z", endDate: "2026-01-27T13:00:00Z", calendarId: "cal-1")
        ]
        Task { @Sendable in
            _ = events
        }
    }

    @Test func testPageOfEventsIsSendable() {
        let page = Page(
            items: [
                CalendarEvent(id: "E1", title: "Event 1", startDate: "2026-01-27T10:00:00Z", endDate: "2026-01-27T11:00:00Z", calendarId: "cal-1")
            ],
            nextCursor: "abc",
            hasMore: true
        )
        Task { @Sendable in
            _ = page
        }
    }
}
