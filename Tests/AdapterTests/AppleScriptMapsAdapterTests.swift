import Testing
import Foundation
@testable import Adapters
@testable import Core
import TestUtilities

/// Tests for the AppleScriptMapsAdapter which uses AppleScript and URL schemes.
///
/// Note: The AppleScript adapter has limitations - it opens Maps app but cannot
/// extract actual location data. These tests verify the adapter correctly builds
/// and executes AppleScript, but actual results are typically empty due to
/// URL scheme limitations.
@Suite("AppleScriptMapsAdapter Tests")
struct AppleScriptMapsAdapterTests {

    // MARK: - Search Tests

    @Test func searchExecutesAppleScript() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        _ = try await adapter.searchLocations(query: "Apple Park", near: nil, limit: 5)

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("Maps") == true)
        #expect(script?.contains("Apple") == true)  // URL-encoded will still contain Apple
    }

    @Test func searchHandlesEmptyResponse() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        let results = try await adapter.searchLocations(query: "NonexistentPlace12345", near: nil, limit: 5)

        #expect(results.isEmpty)
    }

    @Test func searchParsesLocationData() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("""
            Apple Park\t1 Apple Park Way, Cupertino, CA\t37.3349\t-122.0090
            """)

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        let results = try await adapter.searchLocations(query: "Apple Park", near: nil, limit: 5)

        #expect(results.count == 1)
        #expect(results[0].name == "Apple Park")
        #expect(results[0].address == "1 Apple Park Way, Cupertino, CA")
    }

    @Test func searchIncludesNearParameter() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        _ = try await adapter.searchLocations(query: "Coffee", near: "Cupertino", limit: 10)

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("near=") == true)
    }

    @Test func searchThrowsAppleScriptErrorOnFailure() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setError(AppleScriptError.executionFailed(message: "Maps not running"))

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)

        await #expect(throws: AppleScriptError.self) {
            _ = try await adapter.searchLocations(query: "Test", near: nil, limit: 5)
        }
    }

    // MARK: - Nearby Tests

    @Test func nearbyExecutesAppleScript() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        _ = try await adapter.searchNearby(category: "coffee", near: "Cupertino", limit: 5)

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("Maps") == true)
        #expect(script?.contains("coffee") == true)
    }

    @Test func nearbyThrowsForEmptyCategory() async throws {
        let mockRunner = MockAppleScriptRunner()
        let adapter = AppleScriptMapsAdapter(runner: mockRunner)

        await #expect(throws: ValidationError.self) {
            _ = try await adapter.searchNearby(category: "", near: nil, limit: 10)
        }
    }

    // MARK: - Directions Tests

    @Test func directionsReturnsPlaceholderText() async throws {
        let mockRunner = MockAppleScriptRunner()
        // AppleScript adapter returns placeholder text like "Directions from X to Y by mode"
        await mockRunner.setStubResponse("Directions from San Jose to San Francisco by driving")

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        let directions = try await adapter.getDirections(from: "San Jose", to: "San Francisco", mode: "driving")

        #expect(directions != nil)
        #expect(directions?.contains("Directions from") == true)
    }

    @Test func directionsReturnsNilForEmptyResponse() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        let directions = try await adapter.getDirections(from: "A", to: "B", mode: "walking")

        #expect(directions == nil)
    }

    @Test func directionsUsesCorrectModeFlag() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        _ = try await adapter.getDirections(from: "A", to: "B", mode: "transit")

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("dirflg=r") == true)  // "r" is transit mode
    }

    // MARK: - Open Tests

    @Test func openLocationExecutesAppleScript() async throws {
        let mockRunner = MockAppleScriptRunner()
        await mockRunner.setStubResponse("")

        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        try await adapter.openLocation(query: "ApplePark")

        let script = await mockRunner.getLastScript()
        #expect(script?.contains("ApplePark") == true)
        #expect(script?.contains("Maps") == true)
    }

    // MARK: - Sendable Conformance

    @Test func adapterIsSendable() {
        let mockRunner = MockAppleScriptRunner()
        let adapter = AppleScriptMapsAdapter(runner: mockRunner)
        Task { @Sendable in _ = adapter }
    }

    @Test func adapterCanBeCreatedWithDefaultRunner() {
        // This test verifies the default initializer exists
        let adapter = AppleScriptMapsAdapter()
        Task { @Sendable in _ = adapter }
    }
}
