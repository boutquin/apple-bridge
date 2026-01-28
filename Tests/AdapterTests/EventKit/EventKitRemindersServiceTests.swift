import Testing
import Foundation
@testable import Adapters
@testable import Core

@Suite("EventKitRemindersService Tests")
struct EventKitRemindersServiceTests {

    // MARK: - getLists Tests

    @Test("getLists returns reminder lists")
    func testGetListsReturnsLists() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminderLists([
            EKReminderListData(id: "L1", name: "Personal"),
            EKReminderListData(id: "L2", name: "Work")
        ])

        let service = EventKitRemindersService(adapter: mock)
        let lists = try await service.getLists()

        #expect(lists.count == 2)
        #expect(lists[0].name == "Personal")
        #expect(lists[1].name == "Work")
    }

    @Test("getLists returns empty array when no lists")
    func testGetListsReturnsEmptyArray() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitRemindersService(adapter: mock)
        let lists = try await service.getLists()

        #expect(lists.isEmpty)
    }

    @Test("getLists throws PermissionError when access denied")
    func testGetListsThrowsPermissionError() async throws {
        let mock = MockEventKitAdapter()
        await mock.setError(PermissionError.remindersDenied)

        let service = EventKitRemindersService(adapter: mock)

        await #expect(throws: PermissionError.self) {
            _ = try await service.getLists()
        }
    }

    // MARK: - list Tests

    @Test("list returns paginated reminders for list")
    func testListReturnsPaginatedReminders() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Task 1", listId: "L1", isCompleted: false),
            EKReminderData(id: "R2", title: "Task 2", listId: "L1", isCompleted: false),
            EKReminderData(id: "R3", title: "Task 3", listId: "L2", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let page = try await service.list(listId: "L1", limit: 10, includeCompleted: false, cursor: nil)

        #expect(page.items.count == 2)
        #expect(page.items[0].title == "Task 1")
        #expect(page.items[1].title == "Task 2")
    }

    @Test("list respects limit parameter")
    func testListRespectsLimit() async throws {
        let mock = MockEventKitAdapter()
        let reminders = (1...10).map { i in
            EKReminderData(id: "R\(i)", title: "Task \(i)", listId: "L1", isCompleted: false)
        }
        await mock.setStubReminders(reminders)

        let service = EventKitRemindersService(adapter: mock)
        let page = try await service.list(listId: "L1", limit: 5, includeCompleted: false, cursor: nil)

        #expect(page.items.count == 5)
        #expect(page.hasMore == true)
        #expect(page.nextCursor != nil)
    }

    @Test("list filters completed reminders when includeCompleted is false")
    func testListFiltersCompleted() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Done", listId: "L1", isCompleted: true),
            EKReminderData(id: "R2", title: "Pending", listId: "L1", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let page = try await service.list(listId: "L1", limit: 10, includeCompleted: false, cursor: nil)

        #expect(page.items.count == 1)
        #expect(page.items[0].title == "Pending")
    }

    @Test("list includes completed reminders when includeCompleted is true")
    func testListIncludesCompleted() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Done", listId: "L1", isCompleted: true),
            EKReminderData(id: "R2", title: "Pending", listId: "L1", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let page = try await service.list(listId: "L1", limit: 10, includeCompleted: true, cursor: nil)

        #expect(page.items.count == 2)
    }

    // MARK: - search Tests

    @Test("search filters by query in title")
    func testSearchFiltersByTitle() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Buy milk", listId: "L1", isCompleted: false),
            EKReminderData(id: "R2", title: "Call mom", listId: "L1", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let page = try await service.search(query: "milk", limit: 10, includeCompleted: false, cursor: nil)

        #expect(page.items.count == 1)
        #expect(page.items[0].title == "Buy milk")
    }

    @Test("search filters by query in notes")
    func testSearchFiltersByNotes() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Task 1", listId: "L1", isCompleted: false, notes: "Important project work"),
            EKReminderData(id: "R2", title: "Task 2", listId: "L1", isCompleted: false, notes: "Regular stuff")
        ])

        let service = EventKitRemindersService(adapter: mock)
        let page = try await service.search(query: "project", limit: 10, includeCompleted: false, cursor: nil)

        #expect(page.items.count == 1)
        #expect(page.items[0].notes == "Important project work")
    }

    @Test("search is case-insensitive")
    func testSearchIsCaseInsensitive() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "BUY GROCERIES", listId: "L1", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let page = try await service.search(query: "groceries", limit: 10, includeCompleted: false, cursor: nil)

        #expect(page.items.count == 1)
    }

    @Test("search respects limit parameter")
    func testSearchRespectsLimit() async throws {
        let mock = MockEventKitAdapter()
        let reminders = (1...10).map { i in
            EKReminderData(id: "R\(i)", title: "Buy item \(i)", listId: "L1", isCompleted: false)
        }
        await mock.setStubReminders(reminders)

        let service = EventKitRemindersService(adapter: mock)
        let page = try await service.search(query: "Buy", limit: 3, includeCompleted: false, cursor: nil)

        #expect(page.items.count == 3)
        #expect(page.hasMore == true)
    }

    // MARK: - create Tests

    @Test("create returns new reminder ID")
    func testCreateReturnsId() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitRemindersService(adapter: mock)
        let id = try await service.create(
            title: "New Task",
            dueDate: nil,
            notes: nil,
            listId: nil,
            priority: nil
        )

        #expect(!id.isEmpty)
    }

    @Test("create passes correct parameters to adapter")
    func testCreatePassesParameters() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitRemindersService(adapter: mock)
        let dueDate = "2026-01-28T10:00:00Z"
        _ = try await service.create(
            title: "Test Task",
            dueDate: dueDate,
            notes: "Important notes",
            listId: "custom-list",
            priority: 1
        )

        let created = await mock.getCreatedReminders()
        #expect(created.count == 1)
        #expect(created[0].title == "Test Task")
        #expect(created[0].notes == "Important notes")
        #expect(created[0].listId == "custom-list")
        #expect(created[0].priority == 1)
    }

    // MARK: - update Tests

    @Test("update returns updated reminder")
    func testUpdateReturnsUpdated() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Original", listId: "L1", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let patch = ReminderPatch(title: "Updated Title", notes: "New notes")
        let result = try await service.update(id: "R1", patch: patch)

        #expect(result.title == "Updated Title")
        #expect(result.notes == "New notes")
    }

    @Test("update throws notFound for unknown ID")
    func testUpdateThrowsNotFound() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitRemindersService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            _ = try await service.update(id: "nonexistent", patch: ReminderPatch(title: "New"))
        }
    }

    @Test("update preserves unchanged fields")
    func testUpdatePreservesUnchangedFields() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Original", listId: "L1", isCompleted: false, notes: "Keep this", priority: 5)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let patch = ReminderPatch(title: "New Title") // Only updating title
        let result = try await service.update(id: "R1", patch: patch)

        #expect(result.title == "New Title")
        #expect(result.notes == "Keep this")
        #expect(result.priority == 5)
    }

    // MARK: - delete Tests

    @Test("delete removes reminder")
    func testDeleteRemovesReminder() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "To Delete", listId: "L1", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        try await service.delete(id: "R1")

        let deleted = await mock.getDeletedReminderIds()
        #expect(deleted.contains("R1"))
    }

    @Test("delete throws notFound for unknown ID")
    func testDeleteThrowsNotFound() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitRemindersService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            try await service.delete(id: "nonexistent")
        }
    }

    // MARK: - complete Tests

    @Test("complete marks reminder as completed")
    func testCompleteMarksCompleted() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Task", listId: "L1", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let result = try await service.complete(id: "R1")

        #expect(result.isCompleted == true)
    }

    @Test("complete throws notFound for unknown ID")
    func testCompleteThrowsNotFound() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitRemindersService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            _ = try await service.complete(id: "nonexistent")
        }
    }

    @Test("complete preserves other fields")
    func testCompletePreservesOtherFields() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Important Task", listId: "L1", isCompleted: false, notes: "Details here", priority: 1)
        ])

        let service = EventKitRemindersService(adapter: mock)
        let result = try await service.complete(id: "R1")

        #expect(result.isCompleted == true)
        #expect(result.title == "Important Task")
        #expect(result.notes == "Details here")
        #expect(result.priority == 1)
    }

    // MARK: - open Tests

    @Test("open tracks opened reminder")
    func testOpenTracksOpened() async throws {
        let mock = MockEventKitAdapter()
        await mock.setStubReminders([
            EKReminderData(id: "R1", title: "Task", listId: "L1", isCompleted: false)
        ])

        let service = EventKitRemindersService(adapter: mock)
        try await service.open(id: "R1")

        let opened = await mock.getOpenedReminderIds()
        #expect(opened.contains("R1"))
    }

    @Test("open throws notFound for unknown ID")
    func testOpenThrowsNotFound() async throws {
        let mock = MockEventKitAdapter()

        let service = EventKitRemindersService(adapter: mock)

        await #expect(throws: ValidationError.self) {
            try await service.open(id: "nonexistent")
        }
    }

    // MARK: - Service Sendable Tests

    @Test("EventKitRemindersService is Sendable")
    func testServiceIsSendable() async {
        let mock = MockEventKitAdapter()
        let service = EventKitRemindersService(adapter: mock)

        await Task { @Sendable in
            _ = service
        }.value
    }
}
