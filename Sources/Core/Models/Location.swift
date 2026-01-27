import Foundation

/// A location from Apple Maps search results.
///
/// Represents a place with its name, address, and geographic coordinates.
///
/// ## Example
/// ```swift
/// let location = Location(
///     name: "Apple Park",
///     address: "One Apple Park Way, Cupertino, CA",
///     latitude: 37.3349,
///     longitude: -122.0090
/// )
/// ```
public struct Location: Codable, Sendable, Equatable {
    /// Display name of the location.
    public let name: String

    /// Street address, if available.
    public let address: String?

    /// Latitude coordinate in degrees.
    public let latitude: Double?

    /// Longitude coordinate in degrees.
    public let longitude: Double?

    /// Creates a new location.
    /// - Parameters:
    ///   - name: Display name of the location.
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
