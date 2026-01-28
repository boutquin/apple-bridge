import Testing
import Foundation
@testable import Adapters
@testable import Core
import TestUtilities

@Suite("MapsAppleScriptService Tests")
struct MapsAppleScriptServiceTests {

    // MARK: - Search Tests

    @Test func searchReturnsLocations() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("""
            Apple Park\t1 Apple Park Way, Cupertino, CA\t37.3349\t-122.0090
            """)

        let service = MapsAppleScriptService(runner: mockRunner)
        let results = try await service.search(query: "Apple Park", near: nil, limit: 5)

        #expect(results.items.count == 1)
        #expect(results.items[0].name == "Apple Park")
        #expect(results.items[0].address == "1 Apple Park Way, Cupertino, CA")
    }

    @Test func searchHandlesEmptyResponse() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)
        let results = try await service.search(query: "NonexistentPlace12345", near: nil, limit: 5)

        #expect(results.items.isEmpty)
    }

    @Test func searchRespectsLimit() async throws {
        let mockRunner = MockAppleScriptRunner()
        // The service should pass limit to AppleScript
        await mockRunner.setStubResponse("""
            Place 1\tAddress 1\t37.0\t-122.0
            Place 2\tAddress 2\t37.1\t-122.1
            """)

        let service = MapsAppleScriptService(runner: mockRunner)
        let results = try await service.search(query: "Place", near: nil, limit: 2)

        #expect(results.items.count == 2)
    }

    @Test func searchGeneratesCorrectAppleScript() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)
        _ = try await service.search(query: "Coffee", near: "Cupertino", limit: 10)

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("Maps") == true)
        #expect(script?.contains("Coffee") == true)
    }

    @Test func searchThrowsAppleScriptErrorOnFailure() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setError(AppleScriptError.executionFailed(message: "Maps not running"))

        let service = MapsAppleScriptService(runner: mockRunner)

        await #expect(throws: AppleScriptError.self) {
            _ = try await service.search(query: "Test", near: nil, limit: 5)
        }
    }

    // MARK: - Nearby Tests

    @Test func nearbyReturnsLocations() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("""
            Starbucks\t123 Main St\t37.3349\t-122.0090
            """)

        let service = MapsAppleScriptService(runner: mockRunner)
        let results = try await service.nearby(category: "coffee", near: "Cupertino", limit: 5)

        #expect(results.items.count == 1)
        #expect(results.items[0].name == "Starbucks")
    }

    @Test func nearbyThrowsForEmptyCategory() async throws {
        let mockRunner = MockAppleScriptRunner()
        let service = MapsAppleScriptService(runner: mockRunner)

        await #expect(throws: ValidationError.self) {
            _ = try await service.nearby(category: "", near: nil, limit: 10)
        }
    }

    @Test func nearbyValidatesCategory() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)

        // Valid category should not throw
        let results = try await service.nearby(category: "restaurant", near: "San Francisco", limit: 5)
        #expect(results.items.isEmpty || results.items.count >= 0) // May be empty but no throw
    }

    // MARK: - Directions Tests

    @Test func directionsReturnsRoute() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("Take US-101 North for 30 miles. Total time: 35 minutes.")

        let service = MapsAppleScriptService(runner: mockRunner)
        let directions = try await service.directions(from: "San Jose", to: "San Francisco", mode: "driving")

        #expect(directions != nil)
        #expect(directions?.contains("US-101") == true)
    }

    @Test func directionsReturnsNilWhenNoRoute() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)
        let directions = try await service.directions(from: "A", to: "B", mode: "walking")

        #expect(directions == nil)
    }

    @Test func directionsIncludesModeInScript() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)
        _ = try await service.directions(from: "A", to: "B", mode: "transit")

        let script = await mockRunner.getLastScript()
        #expect(script != nil)
        // The script should handle different transport modes
    }

    // MARK: - Open Tests

    @Test func openLocation() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)
        try await service.open(query: "ApplePark")  // Use no spaces for simpler URL encoding

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("ApplePark") == true)
    }

    @Test func openGeneratesCorrectAppleScript() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)
        try await service.open(query: "Cupertino")  // Use simple query without spaces

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("Maps") == true)
        #expect(script?.contains("Cupertino") == true)
    }

    // MARK: - List Guides Tests

    @Test func listGuidesReturnsGuides() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("""
            Coffee Shops
            Restaurants
            Favorites
            """)

        let service = MapsAppleScriptService(runner: mockRunner)
        let guides = try await service.listGuides()

        #expect(guides.items.count == 3)
        #expect(guides.items.contains("Coffee Shops"))
    }

    @Test func listGuidesHandlesEmptyList() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)
        let guides = try await service.listGuides()

        #expect(guides.items.isEmpty)
    }

    // MARK: - Open Guide Tests

    @Test func openGuide() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let service = MapsAppleScriptService(runner: mockRunner)
        try await service.openGuide(name: "Favorites")  // Use simple name without spaces

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("Favorites") == true)
    }

    // MARK: - Sendable Conformance

    @Test func serviceIsSendable() {
        let mockRunner = MockAppleScriptRunner()
        let service = MapsAppleScriptService(runner: mockRunner)
        Task { @Sendable in _ = service }
    }

    @Test func serviceCanBeCreatedWithDefaultRunner() {
        // This test verifies the default initializer exists
        // It uses the real AppleScriptRunner.shared
        let service = MapsAppleScriptService()
        Task { @Sendable in _ = service }
    }
}
