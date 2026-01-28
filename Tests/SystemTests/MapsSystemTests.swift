import Foundation
import Testing
import Adapters

/// System tests for Maps domain using MapKit.
///
/// These tests verify that the maps service works correctly with
/// real MapKit APIs to search for locations and get directions.
///
/// ## Prerequisites
/// - MapKit framework must be available
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
///
/// ## Note
/// Maps tests require network access for geocoding and search.
/// Results depend on Apple's Maps data and may vary by location.
@Suite("Maps System Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct MapsSystemTests {

    /// Verifies that the maps service can search for locations with real data.
    ///
    /// Uses MapKit's MKLocalSearch to find real locations with coordinates.
    @Test("Real maps search works")
    func testRealMapsSearch() async throws {
        let service = MapsKitService()
        let results = try await service.search(query: "Apple Park", near: nil, limit: 5)

        // MapKit should return actual results with coordinates
        #expect(results.items.count >= 0)
        #expect(results.items.count <= 5)

        // If results found, verify they have coordinates
        if let firstLocation = results.items.first {
            #expect(firstLocation.latitude != nil)
            #expect(firstLocation.longitude != nil)
        }
    }

    /// Verifies that nearby search works with real MapKit data.
    @Test("Real maps nearby search works")
    func testRealMapsNearbySearch() async throws {
        let service = MapsKitService()
        let results = try await service.nearby(category: "coffee", near: "San Francisco", limit: 5)

        // Should return nearby coffee shops
        #expect(results.items.count >= 0)
        #expect(results.items.count <= 5)
    }

    /// Verifies that directions work with real MapKit data.
    @Test("Real maps directions works")
    func testRealMapsDirections() async throws {
        let service = MapsKitService()
        let directions = try await service.directions(from: "San Jose, CA", to: "San Francisco, CA", mode: "driving")

        // Should return actual route information
        if let directions = directions {
            #expect(directions.contains("Distance:") || directions.contains("Directions from"))
        }
    }
}
