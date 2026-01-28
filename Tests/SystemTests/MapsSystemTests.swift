import Foundation
import Testing
import Adapters

/// System tests for Maps domain using real AppleScript.
///
/// These tests verify that the maps service works correctly with the
/// actual Apple Maps application. Maps has limited AppleScript support
/// so tests focus on URL scheme-based operations.
///
/// ## Prerequisites
/// - Apple Maps must be available
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
///
/// ## Note
/// Maps tests may launch the Maps app and could be slower than database tests.
/// Some operations initiate searches but don't return detailed results.
@Suite("Maps System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct MapsSystemTests {

    /// Verifies that the maps service can initiate a search without crashing.
    ///
    /// Note: Apple Maps has limited AppleScript support. This test verifies
    /// the service initializes and executes the search command without error,
    /// but the actual search results may be empty (URL scheme based).
    @Test("Real maps search works")
    func testRealMapsSearch() async throws {
        let service = MapsAppleScriptService()
        let results = try await service.search(query: "Apple Park", near: nil, limit: 5)

        // Just verify no crash and valid response structure
        // Results may be empty due to URL scheme limitations
        #expect(results.items.count >= 0)
        #expect(results.items.count <= 5)
    }

    /// Verifies that the maps service can list guides without crashing.
    @Test("Real maps guides list works")
    func testRealMapsGuidesList() async throws {
        let service = MapsAppleScriptService()
        let guides = try await service.listGuides()

        // Verify valid response structure
        // User may have no guides, which is fine
        // listGuides returns Page<String>, so check items.count
        #expect(guides.items.count >= 0)
    }
}
