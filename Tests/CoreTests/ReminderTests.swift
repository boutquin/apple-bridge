import Testing
import Foundation
@testable import Core

@Suite("Reminder Tests")
struct ReminderTests {
    @Test func testReminderRoundTrip() throws {
        let reminder = Reminder(
            id: "R1",
            title: "Buy groceries",
            dueDate: "2026-01-28T10:00:00Z",
            notes: "Milk, eggs, bread",
            isCompleted: false,
            listId: "list-1",
            priority: 1
        )
        let json = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: json)
        #expect(decoded.id == "R1")
        #expect(decoded.title == "Buy groceries")
        #expect(decoded.dueDate == "2026-01-28T10:00:00Z")
        #expect(decoded.notes == "Milk, eggs, bread")
        #expect(decoded.isCompleted == false)
        #expect(decoded.listId == "list-1")
        #expect(decoded.priority == 1)
    }

    @Test func testReminderWithNilOptionals() throws {
        let reminder = Reminder(
            id: "R2",
            title: "Quick task",
            dueDate: nil,
            notes: nil,
            isCompleted: false,
            listId: "list-1",
            priority: nil
        )
        let json = try JSONEncoder().encode(reminder)
        let decoded = try JSONDecoder().decode(Reminder.self, from: json)
        #expect(decoded.dueDate == nil)
        #expect(decoded.notes == nil)
        #expect(decoded.priority == nil)
    }

    @Test func testReminderListRoundTrip() throws {
        let list = ReminderList(id: "L1", name: "Personal")
        let json = try JSONEncoder().encode(list)
        let decoded = try JSONDecoder().decode(ReminderList.self, from: json)
        #expect(decoded.id == "L1")
        #expect(decoded.name == "Personal")
    }

    @Test func testReminderPatchPartialFields() throws {
        let patch = ReminderPatch(
            title: "Updated title",
            dueDate: nil,
            notes: nil,
            listId: nil,
            priority: nil
        )
        let json = try JSONEncoder().encode(patch)
        let decoded = try JSONDecoder().decode(ReminderPatch.self, from: json)
        #expect(decoded.title == "Updated title")
        #expect(decoded.dueDate == nil)
    }

    @Test func testReminderPatchAllFields() throws {
        let patch = ReminderPatch(
            title: "Updated task",
            dueDate: "2026-01-29T12:00:00Z",
            notes: "Updated notes",
            listId: "list-2",
            priority: 5
        )
        let json = try JSONEncoder().encode(patch)
        let decoded = try JSONDecoder().decode(ReminderPatch.self, from: json)
        #expect(decoded.title == "Updated task")
        #expect(decoded.dueDate == "2026-01-29T12:00:00Z")
        #expect(decoded.notes == "Updated notes")
        #expect(decoded.listId == "list-2")
        #expect(decoded.priority == 5)
    }
}
