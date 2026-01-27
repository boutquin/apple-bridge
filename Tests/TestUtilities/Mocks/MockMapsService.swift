import Foundation
import Core

/// Mock implementation of `MapsService` for testing.
public actor MockMapsService: MapsService {

    /// Stubbed locations to return from search operations.
    public var stubLocations: [Location] = []

    /// Stubbed directions to return.
    public var stubDirections: String?

    /// Stubbed guides to return.
    public var stubGuides: [String] = []

    /// Tracks queries that have been opened in Maps.
    public var openedQueries: [String] = []

    /// Tracks guides that have been opened.
    public var openedGuides: [String] = []

    /// Error to throw (if set) for testing error scenarios.
    public var errorToThrow: (any Error)?

    /// Creates a new mock maps service.
    public init() {}

    /// Sets stubbed locations for testing.
    public func setStubLocations(_ locations: [Location]) {
        self.stubLocations = locations
    }

    /// Sets stubbed directions for testing.
    public func setStubDirections(_ directions: String?) {
        self.stubDirections = directions
    }

    /// Sets stubbed guides for testing.
    public func setStubGuides(_ guides: [String]) {
        self.stubGuides = guides
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    /// Gets opened queries for verification.
    public func getOpenedQueries() -> [String] {
        return openedQueries
    }

    /// Gets opened guides for verification.
    public func getOpenedGuides() -> [String] {
        return openedGuides
    }

    public func search(query: String, near: String?, limit: Int) async throws -> Page<Location> {
        if let error = errorToThrow { throw error }

        let filtered = stubLocations.filter { location in
            location.name.localizedCaseInsensitiveContains(query) ||
            (location.address?.localizedCaseInsensitiveContains(query) ?? false)
        }

        let limitedLocations = Array(filtered.prefix(limit))
        let hasMore = filtered.count > limit
        let nextCursor = hasMore ? "mock-cursor-\(limit)" : nil

        return Page(items: limitedLocations, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func nearby(category: String, near: String?, limit: Int) async throws -> Page<Location> {
        if let error = errorToThrow { throw error }

        if category.isEmpty {
            throw ValidationError.missingRequired(field: "category")
        }

        // For mock, just return stub locations
        let limitedLocations = Array(stubLocations.prefix(limit))
        let hasMore = stubLocations.count > limit
        let nextCursor = hasMore ? "mock-cursor-\(limit)" : nil

        return Page(items: limitedLocations, nextCursor: nextCursor, hasMore: hasMore)
    }

    public func directions(from: String, to: String, mode: String) async throws -> String? {
        if let error = errorToThrow { throw error }
        return stubDirections
    }

    public func open(query: String) async throws {
        if let error = errorToThrow { throw error }
        openedQueries.append(query)
    }

    public func listGuides() async throws -> Page<String> {
        if let error = errorToThrow { throw error }
        return Page(items: stubGuides, nextCursor: nil, hasMore: false)
    }

    public func openGuide(name: String) async throws {
        if let error = errorToThrow { throw error }
        openedGuides.append(name)
    }
}
