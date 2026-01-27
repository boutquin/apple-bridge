import Testing
import Foundation
@testable import Core

@Suite("Location Tests")
struct LocationTests {
    @Test func testLocationRoundTrip() throws {
        let location = Location(
            name: "Apple Park",
            address: "One Apple Park Way, Cupertino, CA",
            latitude: 37.3349,
            longitude: -122.0090
        )
        let json = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(Location.self, from: json)
        #expect(decoded.name == "Apple Park")
        #expect(decoded.address == "One Apple Park Way, Cupertino, CA")
        #expect(decoded.latitude == 37.3349)
        #expect(decoded.longitude == -122.0090)
    }

    @Test func testLocationWithNilCoordinates() throws {
        let location = Location(
            name: "Unknown Place",
            address: "123 Main St",
            latitude: nil,
            longitude: nil
        )
        let json = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(Location.self, from: json)
        #expect(decoded.latitude == nil)
        #expect(decoded.longitude == nil)
    }

    @Test func testLocationWithNilAddress() throws {
        let location = Location(
            name: "Pinned Location",
            address: nil,
            latitude: 37.0,
            longitude: -122.0
        )
        let json = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(Location.self, from: json)
        #expect(decoded.address == nil)
        #expect(decoded.latitude == 37.0)
    }

    @Test func testLocationEquality() {
        let loc1 = Location(name: "Test", address: nil, latitude: 37.0, longitude: -122.0)
        let loc2 = Location(name: "Test", address: nil, latitude: 37.0, longitude: -122.0)
        #expect(loc1 == loc2)
    }
}
