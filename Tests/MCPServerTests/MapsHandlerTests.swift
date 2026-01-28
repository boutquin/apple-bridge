import Testing
import Foundation
@testable import MCPServer
@testable import Core
import TestUtilities
import MCP

@Suite("Maps Handler Tests")
struct MapsHandlerTests {

    // MARK: - maps_search Tests

    @Test func searchReturnsLocations() async throws {
        let services = makeTestServices()
        await services.mockMaps.setStubLocations([
            makeTestLocation(name: "Apple Park", address: "1 Apple Park Way")
        ])

        let result = await MapsHandlers.searchLocations(
            services: services,
            arguments: ["query": .string("Apple Park"), "limit": .int(10)]
        )

        #expect(result.isError == false)
        let content = try #require(result.content.first)
        if case .text(let json) = content {
            #expect(json.contains("Apple Park"))
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test func searchRequiresQuery() async throws {
        let services = makeTestServices()

        let result = await MapsHandlers.searchLocations(
            services: services,
            arguments: [:]
        )

        #expect(result.isError == true)
        let content = try #require(result.content.first)
        if case .text(let text) = content {
            #expect(text.contains("query"))
        }
    }

    @Test func searchUsesDefaultLimit() async throws {
        let services = makeTestServices()
        await services.mockMaps.setStubLocations([])

        let result = await MapsHandlers.searchLocations(
            services: services,
            arguments: ["query": .string("test")]
        )

        #expect(result.isError == false)
    }

    @Test func searchPassesNearParameter() async throws {
        let services = makeTestServices()
        await services.mockMaps.setStubLocations([
            makeTestLocation(name: "Coffee Shop")
        ])

        let result = await MapsHandlers.searchLocations(
            services: services,
            arguments: [
                "query": .string("coffee"),
                "near": .string("Cupertino"),
                "limit": .int(5)
            ]
        )

        #expect(result.isError == false)
    }

    // MARK: - maps_directions Tests

    @Test func directionsReturnsRoute() async throws {
        let services = makeTestServices()
        await services.mockMaps.setStubDirections("Take Highway 101 North")

        let result = await MapsHandlers.getDirections(
            services: services,
            arguments: [
                "from": .string("San Jose"),
                "to": .string("San Francisco"),
                "mode": .string("driving")
            ]
        )

        #expect(result.isError == false)
        let content = try #require(result.content.first)
        if case .text(let json) = content {
            #expect(json.contains("Highway 101"))
        }
    }

    @Test func directionsRequiresFrom() async throws {
        let services = makeTestServices()

        let result = await MapsHandlers.getDirections(
            services: services,
            arguments: [
                "to": .string("San Francisco"),
                "mode": .string("driving")
            ]
        )

        #expect(result.isError == true)
    }

    @Test func directionsRequiresTo() async throws {
        let services = makeTestServices()

        let result = await MapsHandlers.getDirections(
            services: services,
            arguments: [
                "from": .string("San Jose"),
                "mode": .string("driving")
            ]
        )

        #expect(result.isError == true)
    }

    @Test func directionsUsesDefaultMode() async throws {
        let services = makeTestServices()
        await services.mockMaps.setStubDirections("Route found")

        let result = await MapsHandlers.getDirections(
            services: services,
            arguments: [
                "from": .string("A"),
                "to": .string("B")
            ]
        )

        #expect(result.isError == false)
    }

    // MARK: - maps_open Tests

    @Test func openLocation() async throws {
        let services = makeTestServices()

        let result = await MapsHandlers.openLocation(
            services: services,
            arguments: ["query": .string("Apple Park")]
        )

        #expect(result.isError == false)

        let opened = await services.mockMaps.getOpenedQueries()
        #expect(opened.contains("Apple Park"))
    }

    @Test func openRequiresQuery() async throws {
        let services = makeTestServices()

        let result = await MapsHandlers.openLocation(
            services: services,
            arguments: [:]
        )

        #expect(result.isError == true)
    }

    // MARK: - maps_nearby Tests

    @Test func nearbyReturnsLocations() async throws {
        let services = makeTestServices()
        await services.mockMaps.setStubLocations([
            makeTestLocation(name: "Starbucks")
        ])

        let result = await MapsHandlers.nearbyLocations(
            services: services,
            arguments: [
                "category": .string("coffee"),
                "near": .string("Cupertino"),
                "limit": .int(10)
            ]
        )

        #expect(result.isError == false)
        let content = try #require(result.content.first)
        if case .text(let json) = content {
            #expect(json.contains("Starbucks"))
        }
    }

    @Test func nearbyRequiresCategory() async throws {
        let services = makeTestServices()

        let result = await MapsHandlers.nearbyLocations(
            services: services,
            arguments: [
                "near": .string("Cupertino")
            ]
        )

        #expect(result.isError == true)
    }

    @Test func nearbyHandlesEmptyCategory() async throws {
        let services = makeTestServices()

        let result = await MapsHandlers.nearbyLocations(
            services: services,
            arguments: [
                "category": .string(""),
                "near": .string("Cupertino")
            ]
        )

        #expect(result.isError == true)
    }

    // MARK: - Error Handling Tests

    @Test func handlerReturnsErrorOnServiceFailure() async throws {
        let services = makeTestServices()
        await services.mockMaps.setError(AppleScriptError.executionFailed(message: "Maps not available"))

        let result = await MapsHandlers.searchLocations(
            services: services,
            arguments: ["query": .string("test")]
        )

        #expect(result.isError == true)
    }
}
