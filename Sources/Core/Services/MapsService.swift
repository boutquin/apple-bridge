import Foundation

/// Protocol for interacting with Apple Maps.
///
/// Defines operations for searching locations, getting directions,
/// and opening locations in Maps. All implementations must be `Sendable` for
/// safe use across actor boundaries.
///
/// ## Available Operations
/// - `search`: Search for locations by query
/// - `nearby`: Find nearby points of interest by category
/// - `directions`: Get directions between two locations
/// - `open`: Open a location in the Maps app
///
/// ## Example
/// ```swift
/// let service: MapsService = MapsKitService()
/// let locations = try await service.search(query: "coffee", near: "Cupertino", limit: 5)
/// ```
public protocol MapsService: Sendable {

    /// Searches for locations matching a query string.
    /// - Parameters:
    ///   - query: Location search query (place name, address, etc.).
    ///   - near: Optional location to search near.
    ///   - limit: Maximum number of results to return.
    /// - Returns: A paginated response containing matching locations.
    func search(query: String, near: String?, limit: Int) async throws -> Page<Location>

    /// Searches for nearby points of interest by category.
    /// - Parameters:
    ///   - category: Category to search for (e.g., "coffee", "restaurant").
    ///   - near: Location to search near (required).
    ///   - limit: Maximum number of results to return.
    /// - Returns: A paginated response containing nearby locations.
    /// - Throws: `ValidationError.missingRequired` if category is empty.
    func nearby(category: String, near: String?, limit: Int) async throws -> Page<Location>

    /// Gets directions between two locations.
    /// - Parameters:
    ///   - from: Starting location (address or place name).
    ///   - to: Destination location (address or place name).
    ///   - mode: Transport mode ("driving", "walking", "transit").
    /// - Returns: Directions description or nil if route not found.
    func directions(from: String, to: String, mode: String) async throws -> String?

    /// Opens a location in the Maps app.
    /// - Parameter query: Location to open (address or place name).
    func open(query: String) async throws
}
