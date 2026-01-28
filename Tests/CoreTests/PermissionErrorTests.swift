import Testing
import Foundation
@testable import Core

@Suite("PermissionError Tests")
struct PermissionErrorTests {
    @Test func testCalendarDeniedMessage() {
        let error = PermissionError.calendarDenied
        #expect(error.userMessage.contains("Calendar"))
        #expect(error.userMessage.contains("System Settings"))
    }

    @Test func testRemindersDeniedMessage() {
        let error = PermissionError.remindersDenied
        #expect(error.userMessage.contains("Reminders"))
        #expect(error.userMessage.contains("System Settings"))
    }

    @Test func testContactsDeniedMessage() {
        let error = PermissionError.contactsDenied
        #expect(error.userMessage.contains("Contacts"))
        #expect(error.userMessage.contains("System Settings"))
    }

    @Test func testFullDiskAccessDeniedMessage() {
        let error = PermissionError.fullDiskAccessDenied()
        #expect(error.userMessage.contains("Full Disk Access"))
        #expect(error.userMessage.contains("System Settings"))
    }

    @Test func testFullDiskAccessDeniedWithContextMessage() {
        let error = PermissionError.fullDiskAccessDenied(context: "Notes")
        #expect(error.userMessage.contains("Full Disk Access"))
        #expect(error.userMessage.contains("Notes"))
        #expect(error.userMessage.contains("System Settings"))
    }

    @Test func testAutomationDeniedMessage() {
        let error = PermissionError.automationDenied(app: "Mail")
        #expect(error.userMessage.contains("Mail"))
        #expect(error.userMessage.contains("Automation"))
    }

    @Test func testAllPermissionErrorsAreSendable() {
        // Compile-time check: can be passed across actor boundaries
        let errors: [PermissionError] = [
            .calendarDenied,
            .remindersDenied,
            .contactsDenied,
            .fullDiskAccessDenied(),
            .automationDenied(app: "Test")
        ]
        Task { @Sendable in
            _ = errors
        }
    }
}
