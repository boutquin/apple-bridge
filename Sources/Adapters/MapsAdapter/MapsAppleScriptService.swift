import Foundation
import Core

/// AppleScript-based implementation of `MapsService`.
///
/// Uses a `MapsAdapterProtocol` to interact with Apple Maps for searching locations,
/// getting directions, and managing guides. This enables dependency injection for testing.
///
/// ## Usage
/// ```swift
/// let service = MapsAppleScriptService()
/// let locations = try await service.search(query: "Coffee", near: "Cupertino", limit: 5)
/// ```
///
/// For testing with a mock adapter:
/// ```swift
/// let adapter = MockMapsAdapter()
/// let service = MapsAppleScriptService(adapter: adapter)
/// ```
public struct MapsAppleScriptService: MapsService, Sendable {

    /// The adapter to use for maps operations.
    private let adapter: any MapsAdapterProtocol

    // MARK: - Initialization

    /// Creates a new Maps service using the default adapter.
    public init() {
        self.adapter = RealMapsAdapter()
    }

    /// Creates a new Maps service with a custom adapter (for testing).
    ///
    /// - Parameter adapter: The maps adapter to use.
    public init(adapter: any MapsAdapterProtocol) {
        self.adapter = adapter
    }

    /// Creates a new Maps service with a custom runner (for backward compatibility).
    ///
    /// - Parameter runner: The AppleScript runner to use.
    public init(runner: any AppleScriptRunnerProtocol) {
        self.adapter = RealMapsAdapter(runner: runner)
    }

    // MARK: - MapsService Protocol

    /// Searches for locations matching a query string.
    ///
    /// - Parameters:
    ///   - query: Location search query (place name, address, etc.).
    ///   - near: Optional location to search near.
    ///   - limit: Maximum number of results to return.
    /// - Returns: A paginated response containing matching locations.
    /// - Throws: `AppleScriptError` if Maps access fails.
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
    /// - Throws: `AppleScriptError` if Maps access fails.
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
    /// - Throws: `AppleScriptError` if Maps access fails.
    public func directions(from: String, to: String, mode: String) async throws -> String? {
        try await adapter.getDirections(from: from, to: to, mode: mode)
    }

    /// Opens a location in the Maps app.
    ///
    /// - Parameter query: Location to open (address or place name).
    /// - Throws: `AppleScriptError` if Maps cannot be opened.
    public func open(query: String) async throws {
        try await adapter.openLocation(query: query)
    }

    /// Lists all saved guides.
    ///
    /// - Returns: A paginated response containing guide names.
    /// - Throws: `AppleScriptError` if Maps access fails.
    ///
    /// Note: Apple Maps has very limited AppleScript support for guides.
    /// This implementation returns available guides through UI scripting.
    public func listGuides() async throws -> Page<String> {
        let guideData = try await adapter.fetchGuides()
        let names = guideData.map { $0.name }
        return Page(items: names, nextCursor: nil, hasMore: false)
    }

    /// Opens a saved guide in the Maps app.
    ///
    /// - Parameter name: Name of the guide to open.
    /// - Throws: `AppleScriptError` if Maps cannot be opened.
    public func openGuide(name: String) async throws {
        try await adapter.openGuide(name: name)
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
