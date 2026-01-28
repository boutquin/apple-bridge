import Foundation
import Core

#if canImport(MapKit)
@preconcurrency import MapKit
#endif

#if canImport(CoreLocation)
@preconcurrency import CoreLocation
#endif

/// MapKit-based implementation of `MapsAdapterProtocol`.
///
/// Uses MapKit's `MKLocalSearch` and `MKDirections` APIs to provide real location
/// search and directions data. This is the primary Maps adapter, providing actual
/// location data with coordinates.
///
/// ## Features
/// - Real location search with coordinates via `MKLocalSearch`
/// - Nearby POI search with category filtering
/// - Actual route directions with distance and travel time via `MKDirections`
/// - Opens locations in Maps app via `MKMapItem.openInMaps()`
///
/// ## Usage
/// ```swift
/// let adapter = MapKitAdapter()
/// let locations = try await adapter.searchLocations(query: "Coffee", near: "Cupertino", limit: 5)
/// for location in locations {
///     print("\(location.name) at \(location.latitude ?? 0), \(location.longitude ?? 0)")
/// }
/// ```
///
/// ## Requirements
/// - macOS 10.9+ (uses MapKit framework)
/// - Location services enabled (optional, improves nearby searches)
public actor MapKitAdapter: MapsAdapterProtocol {

    #if canImport(CoreLocation)
    /// Geocoder for converting addresses to coordinates.
    /// Marked nonisolated(unsafe) because CLGeocoder handles its own thread safety.
    private nonisolated(unsafe) let geocoder = CLGeocoder()
    #endif

    /// Creates a new MapKit adapter.
    public init() {}

    // MARK: - MapsAdapterProtocol

    public func searchLocations(query: String, near: String?, limit: Int) async throws -> [LocationData] {
        #if canImport(MapKit)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        // If "near" is provided, geocode it to set a search region
        if let near = near {
            if let region = try? await geocodeToRegion(address: near) {
                request.region = region
            }
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.prefix(limit).map { item in
            LocationData(
                name: item.name ?? "",
                address: formatAddress(item.placemark),
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
        }
        #else
        return []
        #endif
    }

    public func searchNearby(category: String, near: String?, limit: Int) async throws -> [LocationData] {
        guard !category.isEmpty else {
            throw ValidationError.missingRequired(field: "category")
        }

        #if canImport(MapKit)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category

        // Set search region if "near" is provided
        if let near = near {
            if let region = try? await geocodeToRegion(address: near) {
                request.region = region
            }
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.prefix(limit).map { item in
            LocationData(
                name: item.name ?? "",
                address: formatAddress(item.placemark),
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
        }
        #else
        return []
        #endif
    }

    public func getDirections(from: String, to: String, mode: String) async throws -> String? {
        #if canImport(MapKit) && canImport(CoreLocation)
        // Geocode both addresses
        guard let fromCoordinate = try? await geocodeAddress(from),
              let toCoordinate = try? await geocodeAddress(to) else {
            return nil
        }

        let request = MKDirections.Request()

        let sourcePlacemark = MKPlacemark(coordinate: fromCoordinate)
        request.source = MKMapItem(placemark: sourcePlacemark)

        let destPlacemark = MKPlacemark(coordinate: toCoordinate)
        request.destination = MKMapItem(placemark: destPlacemark)

        request.transportType = mapTransportType(mode)

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            return nil
        }

        return formatRoute(route, from: from, to: to, mode: mode)
        #else
        return nil
        #endif
    }

    public func openLocation(query: String) async throws {
        #if canImport(MapKit)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let item = response.mapItems.first else {
            throw ValidationError.notFound(resource: "location", id: query)
        }

        item.openInMaps()
        #else
        throw ValidationError.notFound(resource: "location", id: query)
        #endif
    }

    // MARK: - Private Helpers

    #if canImport(CoreLocation)
    /// Geocodes an address string to a coordinate.
    private func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D? {
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let location = placemarks.first?.location else {
            return nil
        }
        return location.coordinate
    }

    /// Geocodes an address string to a map region for searching.
    private func geocodeToRegion(address: String, radiusMeters: Double = 10000) async throws -> MKCoordinateRegion? {
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let location = placemarks.first?.location else {
            return nil
        }

        return MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radiusMeters,
            longitudinalMeters: radiusMeters
        )
    }
    #endif

    #if canImport(MapKit)
    /// Formats a placemark's address components into a readable string.
    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var components: [String] = []

        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            if !components.isEmpty {
                components.append(", \(locality)")
            } else {
                components.append(locality)
            }
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }

        let address = components.joined(separator: " ")
        return address.isEmpty ? nil : address
    }

    /// Maps a transport mode string to MKDirectionsTransportType.
    private func mapTransportType(_ mode: String) -> MKDirectionsTransportType {
        switch mode.lowercased() {
        case "walking": return .walking
        case "transit": return .transit
        case "driving": return .automobile
        default: return .automobile
        }
    }

    /// Formats a route into a human-readable description.
    private func formatRoute(_ route: MKRoute, from: String, to: String, mode: String) -> String {
        let distanceKm = route.distance / 1000.0
        let distanceMi = route.distance / 1609.34
        let timeMinutes = Int(route.expectedTravelTime / 60)

        var description = "Directions from \(from) to \(to) by \(mode):\n"
        description += "Distance: \(String(format: "%.1f", distanceKm)) km (\(String(format: "%.1f", distanceMi)) mi)\n"
        description += "Expected travel time: "

        if timeMinutes < 60 {
            description += "\(timeMinutes) minutes"
        } else {
            let hours = timeMinutes / 60
            let mins = timeMinutes % 60
            description += "\(hours) hour\(hours > 1 ? "s" : "")"
            if mins > 0 {
                description += " \(mins) min"
            }
        }

        // Add step-by-step instructions if available
        if !route.steps.isEmpty {
            description += "\n\nSteps:"
            for (index, step) in route.steps.enumerated() where !step.instructions.isEmpty {
                description += "\n\(index + 1). \(step.instructions)"
            }
        }

        return description
    }
    #endif
}
