import Foundation
import Core

/// Service layer implementation of `MapsService` using `MapsAdapterProtocol`.
///
/// Provides a unified interface to Maps functionality through a configurable adapter.
/// By default uses `MapKitAdapter` for real location data, with `AppleScriptMapsAdapter`
/// available as a fallback.
///
/// ## Usage
/// ```swift
/// let service = MapsKitService()
/// let locations = try await service.search(query: "Coffee", near: "Cupertino", limit: 5)
/// ```
///
/// For testing with a mock adapter:
/// ```swift
/// let adapter = MockMapsAdapter()
/// let service = MapsKitService(adapter: adapter)
/// ```
public struct MapsKitService: MapsService, Sendable {

    /// The adapter to use for maps operations.
    private let adapter: any MapsAdapterProtocol

    // MARK: - Initialization

    /// Creates a new Maps service using the default MapKit adapter.
    public init() {
        self.adapter = MapKitAdapter()
    }

    /// Creates a new Maps service with a custom adapter (for testing).
    ///
    /// - Parameter adapter: The maps adapter to use.
    public init(adapter: any MapsAdapterProtocol) {
        self.adapter = adapter
    }

    // MARK: - MapsService Protocol

    /// Searches for locations matching a query string.
    ///
    /// - Parameters:
    ///   - query: Location search query (place name, address, etc.).
    ///   - near: Optional location to search near.
    ///   - limit: Maximum number of results to return.
    /// - Returns: A paginated response containing matching locations.
    public func search(query: String, near: String?, limit: Int) async throws -> Page<Location> {
        let locationData = try await adapter.searchLocations(query: query, near: near, limit: limit)
        let locations = locationData.map { toLocation($0) }
        let hasMore = locationData.count >= limit
        return Page(items: locations, nextCursor: hasMore ? "cursor-\(limit)" : nil, hasMore: hasMore)
    }

    /// Searches for nearby points of interest by category.
    ///
    /// - Parameters:
    ///   - category: Category to search for (e.g., "coffee", "restaurant").
    ///   - near: Location to search near (optional).
    ///   - limit: Maximum number of results to return.
    /// - Returns: A paginated response containing nearby locations.
    /// - Throws: `ValidationError.missingRequired` if category is empty.
    public func nearby(category: String, near: String?, limit: Int) async throws -> Page<Location> {
        let locationData = try await adapter.searchNearby(category: category, near: near, limit: limit)
        let locations = locationData.map { toLocation($0) }
        let hasMore = locationData.count >= limit
        return Page(items: locations, nextCursor: hasMore ? "cursor-\(limit)" : nil, hasMore: hasMore)
    }

    /// Gets directions between two locations.
    ///
    /// - Parameters:
    ///   - from: Starting location (address or place name).
    ///   - to: Destination location (address or place name).
    ///   - mode: Transport mode ("driving", "walking", "transit").
    /// - Returns: Directions description or nil if route not found.
    public func directions(from: String, to: String, mode: String) async throws -> String? {
        try await adapter.getDirections(from: from, to: to, mode: mode)
    }

    /// Opens a location in the Maps app.
    ///
    /// - Parameter query: Location to open (address or place name).
    public func open(query: String) async throws {
        try await adapter.openLocation(query: query)
    }

    // MARK: - Private Helpers

    /// Converts LocationData to Location model.
    private func toLocation(_ data: LocationData) -> Location {
        Location(
            name: data.name,
            address: data.address,
            latitude: data.latitude,
            longitude: data.longitude
        )
    }
}

// MARK: - Backward Compatibility

/// Type alias for backward compatibility.
/// Use `MapsKitService` directly in new code.
@available(*, deprecated, renamed: "MapsKitService")
public typealias MapsAppleScriptService = MapsKitService
