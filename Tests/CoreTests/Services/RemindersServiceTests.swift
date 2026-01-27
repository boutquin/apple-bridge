import Testing
import Foundation
@testable import Core
import TestUtilities

@Suite("RemindersService Protocol Tests")
struct RemindersServiceTests {

    // MARK: - Protocol Conformance Tests

    @Test func testMockRemindersServiceConforms() async throws {
        let mock = MockRemindersService()
        let lists = try await mock.getLists()
        #expect(lists.isEmpty)
    }

    @Test func testMockRemindersServiceIsSendable() {
        let mock = MockRemindersService()
        Task { @Sendable in _ = mock }
    }

    // MARK: - Get Lists Tests

    @Test func testGetListsWithStubData() async throws {
        let mock = MockRemindersService()
        await mock.setStubLists([
            makeTestReminderList(id: "L1", name: "Personal"),
            makeTestReminderList(id: "L2", name: "Work")
        ])

        let lists = try await mock.getLists()
        #expect(lists.count == 2)
        #expect(lists[0].name == "Personal")
    }

    // MARK: - List Reminders Tests

    @Test func testListRemindersWithStubData() async throws {
        let mock = MockRemindersService()
        await mock.setStubReminders([
            makeTestReminder(id: "R1", title: "Buy milk", listId: "L1"),
            makeTestReminder(id: "R2", title: "Call mom", listId: "L1")
        ])

        let page = try await mock.list(listId: "L1", limit: 10, includeCompleted: false, cursor: nil)
        #expect(page.items.count == 2)
    }

    @Test func testListRemindersRespectsLimit() async throws {
        let mock = MockRemindersService()
        await mock.setStubReminders([
            makeTestReminder(id: "R1", listId: "L1"),
            makeTestReminder(id: "R2", listId: "L1"),
            makeTestReminder(id: "R3", listId: "L1")
        ])

        let page = try await mock.list(listId: "L1", limit: 2, includeCompleted: false, cursor: nil)
        #expect(page.items.count == 2)
        #expect(page.hasMore == true)
    }

    @Test func testListRemindersFiltersCompleted() async throws {
        let mock = MockRemindersService()
        await mock.setStubReminders([
            makeTestReminder(id: "R1", isCompleted: false, listId: "L1"),
            makeTestReminder(id: "R2", isCompleted: true, listId: "L1")
        ])

        let page = try await mock.list(listId: "L1", limit: 10, includeCompleted: false, cursor: nil)
        #expect(page.items.count == 1)
        #expect(page.items[0].isCompleted == false)
    }

    // MARK: - Search Reminders Tests

    @Test func testSearchRemindersFilters() async throws {
        let mock = MockRemindersService()
        await mock.setStubReminders([
            makeTestReminder(id: "R1", title: "Buy milk"),
            makeTestReminder(id: "R2", title: "Call mom"),
            makeTestReminder(id: "R3", title: "Buy groceries")
        ])

        let page = try await mock.search(query: "Buy", limit: 10, includeCompleted: false, cursor: nil)
        #expect(page.items.count == 2)
    }

    // MARK: - Create Reminder Tests

    @Test func testCreateReminder() async throws {
        let mock = MockRemindersService()

        let id = try await mock.create(
            title: "New Task",
            dueDate: nil,
            notes: nil,
            listId: nil,
            priority: nil
        )

        #expect(!id.isEmpty)
    }

    // MARK: - Update Reminder Tests

    @Test func testUpdateReminder() async throws {
        let mock = MockRemindersService()
        let testReminder = makeTestReminder(id: "R1", title: "Original Title")
        await mock.setStubReminders([testReminder])

        let patch = ReminderPatch(title: "Updated Title")
        let updated = try await mock.update(id: "R1", patch: patch)

        #expect(updated.title == "Updated Title")
    }

    // MARK: - Delete Reminder Tests

    @Test func testDeleteReminder() async throws {
        let mock = MockRemindersService()
        let testReminder = makeTestReminder(id: "R1")
        await mock.setStubReminders([testReminder])

        try await mock.delete(id: "R1")
        // No throw = success
    }

    // MARK: - Complete Reminder Tests

    @Test func testCompleteReminder() async throws {
        let mock = MockRemindersService()
        let testReminder = makeTestReminder(id: "R1", isCompleted: false)
        await mock.setStubReminders([testReminder])

        let completed = try await mock.complete(id: "R1")
        #expect(completed.isCompleted == true)
    }

    // MARK: - Open Reminder Tests

    @Test func testOpenReminder() async throws {
        let mock = MockRemindersService()
        let testReminder = makeTestReminder(id: "R1")
        await mock.setStubReminders([testReminder])

        try await mock.open(id: "R1")
        // No throw = success
    }

    // MARK: - Not Found Tests

    @Test func testGetReminderNotFoundThrows() async throws {
        let mock = MockRemindersService()
        await mock.setStubReminders([])

        await #expect(throws: (any Error).self) {
            _ = try await mock.update(id: "nonexistent", patch: ReminderPatch(title: "Test"))
        }
    }
}
