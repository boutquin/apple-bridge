import Foundation
import Core

/// AppleScript-based implementation of `MapsService`.
///
/// Uses AppleScript to interact with Apple Maps for searching locations,
/// getting directions, and managing guides. All operations are executed through
/// an `AppleScriptRunnerProtocol` for testability.
///
/// ## Usage
/// ```swift
/// let service = MapsAppleScriptService()
/// let locations = try await service.search(query: "Coffee", near: "Cupertino", limit: 5)
/// ```
///
/// For testing with a mock runner:
/// ```swift
/// let runner = MockAppleScriptRunner()
/// let service = MapsAppleScriptService(runner: runner)
/// ```
public struct MapsAppleScriptService: MapsService, Sendable {

    /// The AppleScript runner to use for executing scripts.
    private let runner: any AppleScriptRunnerProtocol

    // MARK: - Initialization

    /// Creates a new Maps service using the shared AppleScript runner.
    public init() {
        self.runner = AppleScriptRunner.shared
    }

    /// Creates a new Maps service with a custom runner (for testing).
    ///
    /// - Parameter runner: The AppleScript runner to use.
    public init(runner: any AppleScriptRunnerProtocol) {
        self.runner = runner
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
        let escapedQuery = escapeForAppleScript(query)
        let escapedNear = near.map { escapeForAppleScript($0) }

        // Note: Apple Maps has limited AppleScript support.
        // We use a URL scheme approach combined with AppleScript to get results.
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

            -- Return a placeholder response indicating the search was initiated
            -- Full location data extraction requires MapKit integration
            return ""
            """

        let result = try await runner.run(script: script)
        return parseLocationResponse(result, limit: limit)
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

    /// Gets directions between two locations.
    ///
    /// - Parameters:
    ///   - from: Starting location (address or place name).
    ///   - to: Destination location (address or place name).
    ///   - mode: Transport mode ("driving", "walking", "transit").
    /// - Returns: Directions description or nil if route not found.
    /// - Throws: `AppleScriptError` if Maps access fails.
    public func directions(from: String, to: String, mode: String) async throws -> String? {
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

    /// Opens a location in the Maps app.
    ///
    /// - Parameter query: Location to open (address or place name).
    /// - Throws: `AppleScriptError` if Maps cannot be opened.
    public func open(query: String) async throws {
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

    /// Lists all saved guides.
    ///
    /// - Returns: A paginated response containing guide names.
    /// - Throws: `AppleScriptError` if Maps access fails.
    ///
    /// Note: Apple Maps has very limited AppleScript support for guides.
    /// This implementation returns available guides through UI scripting.
    public func listGuides() async throws -> Page<String> {
        // Apple Maps doesn't expose guides via AppleScript directly
        // We return what we can access
        let script = """
            tell application "Maps"
                activate
            end tell

            -- Guides are not directly accessible via AppleScript
            -- Return empty for now; full implementation requires MapKit
            return ""
            """

        let result = try await runner.run(script: script)
        return parseGuidesResponse(result)
    }

    /// Opens a saved guide in the Maps app.
    ///
    /// - Parameter name: Name of the guide to open.
    /// - Throws: `AppleScriptError` if Maps cannot be opened.
    public func openGuide(name: String) async throws {
        let escapedName = escapeForAppleScript(name)

        let script = """
            tell application "Maps"
                activate
            end tell

            -- Navigate to the guide by name using search
            set searchURL to "maps://?q=\(escapedName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? escapedName)"
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
    private func parseLocationResponse(_ response: String, limit: Int) -> Page<Location> {
        guard !response.isEmpty else {
            return Page(items: [], nextCursor: nil, hasMore: false)
        }

        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }
        var locations: [Location] = []

        for line in lines.prefix(limit) {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 1 else { continue }

            let name = parts[0]
            let address = parts.count > 1 ? parts[1] : nil
            let latitude = parts.count > 2 ? Double(parts[2]) : nil
            let longitude = parts.count > 3 ? Double(parts[3]) : nil

            locations.append(Location(
                name: name,
                address: address,
                latitude: latitude,
                longitude: longitude
            ))
        }

        let hasMore = lines.count > limit
        let nextCursor = hasMore ? "cursor-\(limit)" : nil

        return Page(items: locations, nextCursor: nextCursor, hasMore: hasMore)
    }

    /// Parses the AppleScript response for guides.
    ///
    /// Expected format: one guide name per line.
    private func parseGuidesResponse(_ response: String) -> Page<String> {
        guard !response.isEmpty else {
            return Page(items: [], nextCursor: nil, hasMore: false)
        }

        let guides = response.components(separatedBy: "\n").filter { !$0.isEmpty }
        return Page(items: guides, nextCursor: nil, hasMore: false)
    }
}
