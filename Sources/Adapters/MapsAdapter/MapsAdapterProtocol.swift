import Foundation
import Core

// MARK: - Maps Data Transfer Objects

/// Lightweight data representation of a location.
///
/// This struct provides a Sendable, Codable representation of locations
/// that can be safely passed across actor boundaries without requiring direct
/// framework access. Used as the boundary type between adapter implementations
/// (MapKit, AppleScript, etc.) and the service layer.
public struct LocationData: Sendable, Equatable, Codable {
    /// Name of the location (e.g., business name, landmark).
    public let name: String

    /// Street address of the location, if available.
    public let address: String?

    /// Latitude coordinate, if available.
    public let latitude: Double?

    /// Longitude coordinate, if available.
    public let longitude: Double?

    /// Creates a new location data instance.
    /// - Parameters:
    ///   - name: Name of the location.
    ///   - address: Street address.
    ///   - latitude: Latitude coordinate.
    ///   - longitude: Longitude coordinate.
    public init(
        name: String,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Lightweight data representation of a guide (saved place collection).
///
/// This struct provides a Sendable representation of Maps guides that can be
/// safely passed across actor boundaries. Used as the boundary type between
/// adapter implementations and the service layer.
public struct GuideData: Sendable, Equatable, Codable {
    /// Name of the guide.
    public let name: String

    /// Creates a new guide data instance.
    /// - Parameter name: Name of the guide.
    public init(name: String) {
        self.name = name
    }
}

// MARK: - Protocol

/// Protocol for interacting with Apple Maps.
///
/// This protocol abstracts maps operations to enable testing with mock implementations
/// and to support multiple backend implementations (MapKit, AppleScript, etc.).
/// All implementations must be `Sendable` for safe use across actor boundaries.
///
/// ## Implementation Notes
/// - MapKit implementation uses MKLocalSearch for location search
/// - AppleScript implementation uses URL schemes for basic operations
/// - The protocol uses generic data transfer objects (LocationData, GuideData) to
///   decouple from specific framework types
///
/// ## Example
/// ```swift
/// let adapter: MapsAdapterProtocol = RealMapsAdapter()
/// let locations = try await adapter.searchLocations(query: "Coffee", near: "Cupertino", limit: 5)
/// ```
public protocol MapsAdapterProtocol: Sendable {

    // MARK: - Search Operations

    /// Searches for locations matching a query string.
    /// - Parameters:
    ///   - query: Location search query (place name, address, etc.).
    ///   - near: Optional location to search near.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Array of matching location data objects.
    /// - Throws: `AppleScriptError` if Maps access fails.
    func searchLocations(query: String, near: String?, limit: Int) async throws -> [LocationData]

    /// Searches for nearby points of interest by category.
    /// - Parameters:
    ///   - category: Category to search for (e.g., "coffee", "restaurant").
    ///   - near: Location to search near (optional).
    ///   - limit: Maximum number of results to return.
    /// - Returns: Array of nearby location data objects.
    /// - Throws: `ValidationError.missingRequired` if category is empty.
    /// - Throws: `AppleScriptError` if Maps access fails.
    func searchNearby(category: String, near: String?, limit: Int) async throws -> [LocationData]

    // MARK: - Directions

    /// Gets directions between two locations.
    /// - Parameters:
    ///   - from: Starting location (address or place name).
    ///   - to: Destination location (address or place name).
    ///   - mode: Transport mode ("driving", "walking", "transit").
    /// - Returns: Directions description or nil if route not found.
    /// - Throws: `AppleScriptError` if Maps access fails.
    func getDirections(from: String, to: String, mode: String) async throws -> String?

    // MARK: - Open Operations

    /// Opens a location in the Maps app.
    /// - Parameter query: Location to open (address or place name).
    /// - Throws: `AppleScriptError` if Maps cannot be opened.
    func openLocation(query: String) async throws

    // MARK: - Guide Operations

    /// Lists all saved guides.
    /// - Returns: Array of guide data objects.
    /// - Throws: `AppleScriptError` if Maps access fails.
    func fetchGuides() async throws -> [GuideData]

    /// Opens a saved guide in the Maps app.
    /// - Parameter name: Name of the guide to open.
    /// - Throws: `AppleScriptError` if Maps cannot be opened.
    func openGuide(name: String) async throws
}
