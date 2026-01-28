import Foundation
import Testing
import Adapters

/// System tests for Messages domain using real SQLite database.
///
/// These tests verify that the messages service works correctly with the
/// actual system Messages database. They require Full Disk Access permission.
///
/// ## Prerequisites
/// - Full Disk Access must be granted to the test runner
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
@Suite("Messages System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct MessagesSystemTests {

    /// Verifies that the messages service can list chats without crashing.
    @Test("Real messages chat list works")
    func testRealMessagesChatList() async throws {
        let service = MessagesSQLiteService()
        let chats = try await service.chats(limit: 5)

        // Just verify no crash and valid response structure
        // chats() returns [(id: String, displayName: String)]
        #expect(chats.count >= 0)
        #expect(chats.count <= 5)
    }

    /// Verifies that the messages service can list unread messages.
    @Test("Real messages unread works")
    func testRealMessagesUnread() async throws {
        let service = MessagesSQLiteService()
        let unread = try await service.unread(limit: 5)

        // Verify valid response structure
        // unread() returns [Message]
        #expect(unread.count >= 0)
        #expect(unread.count <= 5)
    }
}
