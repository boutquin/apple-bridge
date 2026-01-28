import Testing
import Foundation
@testable import Adapters
@testable import Core
import TestUtilities

@Suite("MapsKitService Tests")
struct MapsKitServiceTests {

    // MARK: - Search Tests

    @Test func searchReturnsLocations() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubLocations([
            LocationData(name: "Apple Park", address: "1 Apple Park Way, Cupertino, CA", latitude: 37.3349, longitude: -122.0090)
        ])

        let service = MapsKitService(adapter: mockAdapter)
        let results = try await service.search(query: "Apple Park", near: nil, limit: 5)

        #expect(results.items.count == 1)
        #expect(results.items[0].name == "Apple Park")
        #expect(results.items[0].address == "1 Apple Park Way, Cupertino, CA")
        #expect(results.items[0].latitude == 37.3349)
        #expect(results.items[0].longitude == -122.0090)
    }

    @Test func searchHandlesEmptyResponse() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubLocations([])

        let service = MapsKitService(adapter: mockAdapter)
        let results = try await service.search(query: "NonexistentPlace12345", near: nil, limit: 5)

        #expect(results.items.isEmpty)
    }

    @Test func searchRespectsLimit() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubLocations([
            LocationData(name: "Place 1", address: "Address 1", latitude: 37.0, longitude: -122.0),
            LocationData(name: "Place 2", address: "Address 2", latitude: 37.1, longitude: -122.1),
            LocationData(name: "Place 3", address: "Address 3", latitude: 37.2, longitude: -122.2)
        ])

        let service = MapsKitService(adapter: mockAdapter)
        let results = try await service.search(query: "Place", near: nil, limit: 2)

        #expect(results.items.count == 2)
    }

    @Test func searchPassesParametersToAdapter() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubLocations([])

        let service = MapsKitService(adapter: mockAdapter)
        _ = try await service.search(query: "Coffee", near: "Cupertino", limit: 10)

        let queries = await mockAdapter.getSearchQueries()
        #expect(queries.count == 1)
        #expect(queries[0].query == "Coffee")
        #expect(queries[0].near == "Cupertino")
        #expect(queries[0].limit == 10)
    }

    // MARK: - Nearby Tests

    @Test func nearbyReturnsLocations() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubLocations([
            LocationData(name: "Starbucks", address: "123 Main St", latitude: 37.3349, longitude: -122.0090)
        ])

        let service = MapsKitService(adapter: mockAdapter)
        let results = try await service.nearby(category: "coffee", near: "Cupertino", limit: 5)

        #expect(results.items.count == 1)
        #expect(results.items[0].name == "Starbucks")
    }

    @Test func nearbyThrowsForEmptyCategory() async throws {
        let mockAdapter = MockMapsAdapter()
        let service = MapsKitService(adapter: mockAdapter)

        await #expect(throws: ValidationError.self) {
            _ = try await service.nearby(category: "", near: nil, limit: 10)
        }
    }

    @Test func nearbyPassesParametersToAdapter() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubLocations([])

        let service = MapsKitService(adapter: mockAdapter)
        _ = try await service.nearby(category: "restaurant", near: "San Francisco", limit: 5)

        let searches = await mockAdapter.getNearbySearches()
        #expect(searches.count == 1)
        #expect(searches[0].category == "restaurant")
        #expect(searches[0].near == "San Francisco")
        #expect(searches[0].limit == 5)
    }

    // MARK: - Directions Tests

    @Test func directionsReturnsRoute() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubDirections("Directions from San Jose to San Francisco by driving:\nDistance: 77.5 km (48.2 mi)\nExpected travel time: 53 minutes")

        let service = MapsKitService(adapter: mockAdapter)
        let directions = try await service.directions(from: "San Jose", to: "San Francisco", mode: "driving")

        #expect(directions != nil)
        #expect(directions?.contains("Distance:") == true)
        #expect(directions?.contains("travel time") == true)
    }

    @Test func directionsReturnsNilWhenNoRoute() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubDirections(nil)

        let service = MapsKitService(adapter: mockAdapter)
        let directions = try await service.directions(from: "A", to: "B", mode: "walking")

        #expect(directions == nil)
    }

    @Test func directionsPassesModeToAdapter() async throws {
        let mockAdapter = MockMapsAdapter()
        await mockAdapter.setStubDirections(nil)

        let service = MapsKitService(adapter: mockAdapter)
        _ = try await service.directions(from: "A", to: "B", mode: "transit")

        let requests = await mockAdapter.getDirectionsRequests()
        #expect(requests.count == 1)
        #expect(requests[0].from == "A")
        #expect(requests[0].to == "B")
        #expect(requests[0].mode == "transit")
    }

    // MARK: - Open Tests

    @Test func openLocation() async throws {
        let mockAdapter = MockMapsAdapter()
        let service = MapsKitService(adapter: mockAdapter)

        try await service.open(query: "Apple Park")

        let opened = await mockAdapter.getOpenedLocations()
        #expect(opened.count == 1)
        #expect(opened[0] == "Apple Park")
    }

    // MARK: - Sendable Conformance

    @Test func serviceIsSendable() {
        let mockAdapter = MockMapsAdapter()
        let service = MapsKitService(adapter: mockAdapter)
        Task { @Sendable in _ = service }
    }

    @Test func serviceCanBeCreatedWithDefaultAdapter() {
        // This test verifies the default initializer exists
        // It uses the real MapKitAdapter
        let service = MapsKitService()
        Task { @Sendable in _ = service }
    }
}
