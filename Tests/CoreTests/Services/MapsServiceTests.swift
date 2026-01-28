import Testing
import Foundation
@testable import Core
import TestUtilities

@Suite("MapsService Protocol Tests")
struct MapsServiceTests {

    // MARK: - Protocol Conformance Tests

    @Test func testMockMapsServiceConforms() async throws {
        let mock = MockMapsService()
        let page = try await mock.search(query: "test", near: nil, limit: 10)
        #expect(page.items.isEmpty)
    }

    @Test func testMockMapsServiceIsSendable() {
        let mock = MockMapsService()
        Task { @Sendable in _ = mock }
    }

    // MARK: - Search Tests

    @Test func testSearchLocationsWithStubData() async throws {
        let mock = MockMapsService()
        await mock.setStubLocations([
            makeTestLocation(name: "Coffee Shop"),
            makeTestLocation(name: "Tea House")
        ])

        let page = try await mock.search(query: "Coffee", near: nil, limit: 10)
        #expect(page.items.count == 1)
        #expect(page.items[0].name == "Coffee Shop")
    }

    @Test func testSearchLocationsRespectsLimit() async throws {
        let mock = MockMapsService()
        await mock.setStubLocations([
            makeTestLocation(name: "Place 1"),
            makeTestLocation(name: "Place 2"),
            makeTestLocation(name: "Place 3")
        ])

        let page = try await mock.search(query: "Place", near: nil, limit: 2)
        #expect(page.items.count == 2)
        #expect(page.hasMore == true)
    }

    // MARK: - Nearby Tests

    @Test func testNearbyLocations() async throws {
        let mock = MockMapsService()
        await mock.setStubLocations([
            makeTestLocation(name: "Starbucks")
        ])

        let page = try await mock.nearby(category: "coffee", near: "Cupertino", limit: 10)
        #expect(page.items.count == 1)
    }

    @Test func testNearbyEmptyCategoryThrows() async throws {
        let mock = MockMapsService()

        await #expect(throws: (any Error).self) {
            _ = try await mock.nearby(category: "", near: nil, limit: 10)
        }
    }

    // MARK: - Directions Tests

    @Test func testGetDirections() async throws {
        let mock = MockMapsService()
        await mock.setStubDirections("Take Highway 101 North for 5 miles")

        let directions = try await mock.directions(from: "San Jose", to: "San Francisco", mode: "driving")
        #expect(directions == "Take Highway 101 North for 5 miles")
    }

    @Test func testGetDirectionsReturnsNilWhenNoRoute() async throws {
        let mock = MockMapsService()
        await mock.setStubDirections(nil)

        let directions = try await mock.directions(from: "A", to: "B", mode: "walking")
        #expect(directions == nil)
    }

    // MARK: - Open Location Tests

    @Test func testOpenLocation() async throws {
        let mock = MockMapsService()

        try await mock.open(query: "Apple Park")

        let opened = await mock.getOpenedQueries()
        #expect(opened.count == 1)
        #expect(opened[0] == "Apple Park")
    }

}
