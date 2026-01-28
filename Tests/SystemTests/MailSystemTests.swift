import Foundation
import Testing
import Adapters

/// System tests for Mail domain using real AppleScript.
///
/// These tests verify that the mail service works correctly with the
/// actual Apple Mail application. They require Mail to be running and
/// configured.
///
/// ## Prerequisites
/// - Apple Mail must be set up with at least one account
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
///
/// ## Note
/// Mail tests may launch the Mail app and could be slower than database tests.
@Suite("Mail System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct MailSystemTests {

    /// Verifies that the mail service can list unread emails without crashing.
    @Test("Real mail unread works")
    func testRealMailUnread() async throws {
        let service = MailAppleScriptService()
        let emails = try await service.unread(limit: 3, includeBody: false)

        // Just verify no crash and valid response structure
        #expect(emails.count >= 0)
        #expect(emails.count <= 3)
    }

    /// Verifies that the mail service can search emails without crashing.
    @Test("Real mail search works")
    func testRealMailSearch() async throws {
        let service = MailAppleScriptService()
        // Search for a common term
        let emails = try await service.search(query: "test", limit: 3, includeBody: false)

        // Verify valid response structure
        #expect(emails.count >= 0)
        #expect(emails.count <= 3)
    }
}
