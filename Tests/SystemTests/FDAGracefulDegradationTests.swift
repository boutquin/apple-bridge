import Foundation
import Testing
import TestUtilities

/// Manual QA tests for Full Disk Access (FDA) graceful degradation.
///
/// These tests verify that the apple-bridge server returns helpful error messages
/// when FDA permission is denied. They cannot be automated in CI because they
/// require specific permission states.
///
/// ## Manual QA Checklist
/// 1. Build apple-bridge in release mode: `swift build -c release`
/// 2. Remove FDA permission: System Settings → Privacy & Security → Full Disk Access → uncheck apple-bridge
/// 3. Set environment variables:
///    ```bash
///    export APPLE_BRIDGE_SYSTEM_TESTS=1
///    export APPLE_BRIDGE_MANUAL_QA=1
///    ```
/// 4. Run: `swift test --filter testNotesFDADeniedReturnsPermissionError`
/// 5. Verify test passes (error message contains remediation steps)
/// 6. Re-grant FDA permission after testing
@Suite("FDA Graceful Degradation Tests",
       .enabled(if: SystemTestHelper.systemTestsEnabled && SystemTestHelper.manualQAEnabled))
struct FDAGracefulDegradationTests {

    /// Verifies that Notes operations return helpful error when FDA is denied.
    ///
    /// When Full Disk Access is denied, the notes_search tool should return:
    /// - Error code: PERMISSION_DENIED
    /// - Message mentioning "Full Disk Access"
    /// - Remediation instructions mentioning "System Settings"
    ///
    /// ## IMPORTANT: Manual QA Test
    /// This test requires FDA to be DENIED for the apple-bridge binary.
    /// Run only after removing FDA permission in System Settings.
    @Test("Notes FDA denied returns permission error with remediation")
    func testNotesFDADeniedReturnsPermissionError() async throws {
        let (stdout, _) = try await ProcessRunner.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"notes_search","arguments":{"searchText":"test"}}}
        """)

        // Verify error response contains expected elements
        #expect(stdout.contains("PERMISSION_DENIED"),
                "Expected PERMISSION_DENIED error code in response")
        #expect(stdout.contains("Full Disk Access") || stdout.contains("full disk access"),
                "Expected mention of Full Disk Access in error message")
        #expect(stdout.contains("System Settings") || stdout.contains("System Preferences"),
                "Expected remediation instructions in error message")
    }

    /// Verifies that Messages operations return helpful error when FDA is denied.
    ///
    /// Similar to Notes, Messages requires FDA to read the chat.db database.
    @Test("Messages FDA denied returns permission error with remediation")
    func testMessagesFDADeniedReturnsPermissionError() async throws {
        let (stdout, _) = try await ProcessRunner.runAppleBridge(input: """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}}}
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"messages_unread","arguments":{}}}
        """)

        // Verify error response contains expected elements
        #expect(stdout.contains("PERMISSION_DENIED"),
                "Expected PERMISSION_DENIED error code in response")
        #expect(stdout.contains("Full Disk Access") || stdout.contains("full disk access"),
                "Expected mention of Full Disk Access in error message")
    }
}
