import Foundation
import Core
import Adapters

/// Mock implementation of `MapsAdapterProtocol` for testing.
///
/// Provides stubbed data and tracks method calls for verification in tests.
/// All methods are actor-isolated for thread safety.
public actor MockMapsAdapter: MapsAdapterProtocol {

    // MARK: - Stub Data

    /// Stubbed locations to return from search operations.
    private var stubLocations: [LocationData] = []

    /// Stubbed guides to return.
    private var stubGuides: [GuideData] = []

    /// Stubbed directions response.
    private var stubDirections: String?

    /// Error to throw (if set) for testing error scenarios.
    private var errorToThrow: (any Error)?

    // MARK: - Tracking

    /// Tracks search queries made.
    private var searchQueries: [(query: String, near: String?, limit: Int)] = []

    /// Tracks nearby searches made.
    private var nearbySearches: [(category: String, near: String?, limit: Int)] = []

    /// Tracks directions requests made.
    private var directionsRequests: [(from: String, to: String, mode: String)] = []

    /// Tracks locations opened.
    private var openedLocations: [String] = []

    /// Tracks guides opened.
    private var openedGuides: [String] = []

    // MARK: - Initialization

    /// Creates a new mock maps adapter.
    public init() {}

    // MARK: - Setup Methods

    /// Sets stubbed locations for testing.
    public func setStubLocations(_ locations: [LocationData]) {
        self.stubLocations = locations
    }

    /// Sets stubbed guides for testing.
    public func setStubGuides(_ guides: [GuideData]) {
        self.stubGuides = guides
    }

    /// Sets stubbed directions response.
    public func setStubDirections(_ directions: String?) {
        self.stubDirections = directions
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    // MARK: - Verification Methods

    /// Gets the search queries for verification.
    public func getSearchQueries() -> [(query: String, near: String?, limit: Int)] {
        return searchQueries
    }

    /// Gets the nearby searches for verification.
    public func getNearbySearches() -> [(category: String, near: String?, limit: Int)] {
        return nearbySearches
    }

    /// Gets the directions requests for verification.
    public func getDirectionsRequests() -> [(from: String, to: String, mode: String)] {
        return directionsRequests
    }

    /// Gets the opened locations for verification.
    public func getOpenedLocations() -> [String] {
        return openedLocations
    }

    /// Gets the opened guides for verification.
    public func getOpenedGuides() -> [String] {
        return openedGuides
    }

    // MARK: - MapsAdapterProtocol

    public func searchLocations(query: String, near: String?, limit: Int) async throws -> [LocationData] {
        if let error = errorToThrow { throw error }
        searchQueries.append((query: query, near: near, limit: limit))
        return Array(stubLocations.prefix(limit))
    }

    public func searchNearby(category: String, near: String?, limit: Int) async throws -> [LocationData] {
        if let error = errorToThrow { throw error }

        guard !category.isEmpty else {
            throw ValidationError.missingRequired(field: "category")
        }

        nearbySearches.append((category: category, near: near, limit: limit))
        return Array(stubLocations.prefix(limit))
    }

    public func getDirections(from: String, to: String, mode: String) async throws -> String? {
        if let error = errorToThrow { throw error }
        directionsRequests.append((from: from, to: to, mode: mode))
        return stubDirections
    }

    public func openLocation(query: String) async throws {
        if let error = errorToThrow { throw error }
        openedLocations.append(query)
    }

    public func fetchGuides() async throws -> [GuideData] {
        if let error = errorToThrow { throw error }
        return stubGuides
    }

    public func openGuide(name: String) async throws {
        if let error = errorToThrow { throw error }
        openedGuides.append(name)
    }
}
