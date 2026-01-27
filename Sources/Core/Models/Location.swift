import Foundation

/// Location model for Maps results.
public struct Location: Codable, Sendable, Equatable {
    public let name: String
    public let address: String?
    public let latitude: Double?
    public let longitude: Double?

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
