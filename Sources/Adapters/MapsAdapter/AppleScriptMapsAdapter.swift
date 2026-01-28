import Foundation
import Core

/// AppleScript-based implementation of `MapsAdapterProtocol`.
///
/// Uses AppleScript and URL schemes to interact with Apple Maps.
/// This implementation opens Maps.app and performs searches via URL schemes,
/// but cannot return actual location data (returns empty arrays).
/// For real location data, use `MapKitAdapter` instead.
///
/// ## Limitations
/// - Cannot extract location data from Maps app (returns empty arrays)
/// - Directions returns placeholder text, not actual route information
/// - Only opens Maps app with search query, doesn't return results
///
/// ## Usage
/// ```swift
/// let adapter = AppleScriptMapsAdapter()
/// try await adapter.openLocation(query: "Apple Park")  // Opens Maps
/// ```
///
/// For testing with a mock runner:
/// ```swift
/// let runner = MockAppleScriptRunner()
/// let adapter = AppleScriptMapsAdapter(runner: runner)
/// ```
public struct AppleScriptMapsAdapter: MapsAdapterProtocol, Sendable {

    /// The AppleScript runner to use for executing scripts.
    private let runner: any AppleScriptRunnerProtocol

    // MARK: - Initialization

    /// Creates a new Maps adapter using the shared AppleScript runner.
    public init() {
        self.runner = AppleScriptRunner.shared
    }

    /// Creates a new Maps adapter with a custom runner (for testing).
    ///
    /// - Parameter runner: The AppleScript runner to use.
    public init(runner: any AppleScriptRunnerProtocol) {
        self.runner = runner
    }

    // MARK: - MapsAdapterProtocol

    public func searchLocations(query: String, near: String?, limit: Int) async throws -> [LocationData] {
        let escapedQuery = escapeForAppleScript(query)
        let escapedNear = near.map { escapeForAppleScript($0) }

        let nearParam = escapedNear.map { "&near=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)" } ?? ""
        let script = """
            tell application "Maps"
                activate
            end tell

            -- Search using URL scheme
            set searchURL to "maps://?q=\(escapedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? escapedQuery)\(nearParam)"
            do shell script "open " & quoted form of searchURL

            -- Wait briefly for Maps to process
            delay 0.5

            -- Return empty - AppleScript cannot extract location data from Maps
            return ""
            """

        let result = try await runner.run(script: script)
        return parseLocationResponse(result, limit: limit)
    }

    public func searchNearby(category: String, near: String?, limit: Int) async throws -> [LocationData] {
        guard !category.isEmpty else {
            throw ValidationError.missingRequired(field: "category")
        }

        let escapedCategory = escapeForAppleScript(category)
        let nearClause = near.map { escapeForAppleScript($0) } ?? ""

        let script = """
            tell application "Maps"
                activate
            end tell

            -- Search nearby using URL scheme
            set searchURL to "maps://?q=\(escapedCategory.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? escapedCategory)\(nearClause.isEmpty ? "" : "&near=\(nearClause.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nearClause)")"
            do shell script "open " & quoted form of searchURL

            delay 0.5
            return ""
            """

        let result = try await runner.run(script: script)
        return parseLocationResponse(result, limit: limit)
    }

    public func getDirections(from: String, to: String, mode: String) async throws -> String? {
        let escapedFrom = escapeForAppleScript(from)
        let escapedTo = escapeForAppleScript(to)
        let modeParam = mapTransportMode(mode)

        let script = """
            tell application "Maps"
                activate
            end tell

            -- Open directions using URL scheme
            set dirURL to "maps://?saddr=\(escapedFrom.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? escapedFrom)&daddr=\(escapedTo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? escapedTo)&dirflg=\(modeParam)"
            do shell script "open " & quoted form of dirURL

            delay 0.5

            -- Note: Extracting actual directions text requires MapKit
            -- Return the route parameters as confirmation
            return "Directions from \(escapedFrom) to \(escapedTo) by \(mode)"
            """

        let result = try await runner.run(script: script)
        return result.isEmpty ? nil : result
    }

    public func openLocation(query: String) async throws {
        let escapedQuery = escapeForAppleScript(query)

        let script = """
            tell application "Maps"
                activate
            end tell

            set searchURL to "maps://?q=\(escapedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? escapedQuery)"
            do shell script "open " & quoted form of searchURL
            """

        _ = try await runner.run(script: script)
    }

    // MARK: - Private Helpers

    /// Escapes a string for use in AppleScript.
    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Maps transport mode string to Maps URL parameter.
    private func mapTransportMode(_ mode: String) -> String {
        switch mode.lowercased() {
        case "walking": return "w"
        case "transit": return "r"
        case "driving": return "d"
        default: return "d" // Default to driving
        }
    }

    /// Parses the AppleScript response for locations.
    ///
    /// Expected format: name\taddress\tlatitude\tlongitude (one per line)
    private func parseLocationResponse(_ response: String, limit: Int) -> [LocationData] {
        guard !response.isEmpty else {
            return []
        }

        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }
        var locations: [LocationData] = []

        for line in lines.prefix(limit) {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 1 else { continue }

            let name = parts[0]
            let address = parts.count > 1 ? parts[1] : nil
            let latitude = parts.count > 2 ? Double(parts[2]) : nil
            let longitude = parts.count > 3 ? Double(parts[3]) : nil

            locations.append(LocationData(
                name: name,
                address: address,
                latitude: latitude,
                longitude: longitude
            ))
        }

        return locations
    }
}

// MARK: - Backward Compatibility

/// Type alias for backward compatibility.
/// Use `AppleScriptMapsAdapter` directly in new code.
@available(*, deprecated, renamed: "AppleScriptMapsAdapter")
public typealias RealMapsAdapter = AppleScriptMapsAdapter
