import Foundation
import MCP
import Core

/// MCP handlers for Maps domain tools.
///
/// Provides handlers for the 6 Maps tools:
/// - `maps_search`: Search for locations
/// - `maps_directions`: Get directions between locations
/// - `maps_open`: Open a location in Maps
/// - `maps_list_guides`: List saved guides
/// - `maps_open_guide`: Open a guide in Maps
/// - `maps_nearby`: Find nearby places by category
enum MapsHandlers {

    // MARK: - Response Types

    /// Response for successful open operations.
    private struct OpenResponse: Encodable {
        let opened: Bool
        let query: String
    }

    /// Response for successful directions operations.
    private struct DirectionsResponse: Encodable {
        let from: String
        let to: String
        let mode: String
        let directions: String?
    }

    /// Response for successful guide operations.
    private struct GuideResponse: Encodable {
        let opened: Bool
        let name: String
    }

    // MARK: - maps_search

    /// Searches for locations matching a query.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: query (required), near (optional), limit (optional).
    /// - Returns: JSON array of matching locations.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func searchLocations(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let query = HandlerUtilities.extractString(from: arguments, key: "query") else {
            return HandlerUtilities.missingRequiredParameter("query")
        }

        let near = HandlerUtilities.extractString(from: arguments, key: "near")
        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 10

        do {
            let page = try await services.maps.search(query: query, near: near, limit: limit)
            return HandlerUtilities.successResult(page)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - maps_directions

    /// Gets directions between two locations.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: from (required), to (required), mode (optional).
    /// - Returns: Directions information.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func getDirections(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let from = HandlerUtilities.extractString(from: arguments, key: "from") else {
            return HandlerUtilities.missingRequiredParameter("from")
        }

        guard let to = HandlerUtilities.extractString(from: arguments, key: "to") else {
            return HandlerUtilities.missingRequiredParameter("to")
        }

        let mode = HandlerUtilities.extractString(from: arguments, key: "mode") ?? "driving"

        do {
            let directions = try await services.maps.directions(from: from, to: to, mode: mode)
            let response = DirectionsResponse(from: from, to: to, mode: mode, directions: directions)
            return HandlerUtilities.successResult(response)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - maps_open

    /// Opens a location in the Maps app.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: query (required).
    /// - Returns: Success confirmation.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func openLocation(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let query = HandlerUtilities.extractString(from: arguments, key: "query") else {
            return HandlerUtilities.missingRequiredParameter("query")
        }

        do {
            try await services.maps.open(query: query)
            let response = OpenResponse(opened: true, query: query)
            return HandlerUtilities.successResult(response)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - maps_list_guides

    /// Lists all saved guides.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: None required.
    /// - Returns: JSON array of guide names.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func listGuides(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        do {
            let page = try await services.maps.listGuides()
            return HandlerUtilities.successResult(page)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - maps_open_guide

    /// Opens a saved guide in the Maps app.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: name (required).
    /// - Returns: Success confirmation.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func openGuide(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let name = HandlerUtilities.extractString(from: arguments, key: "name") else {
            return HandlerUtilities.missingRequiredParameter("name")
        }

        do {
            try await services.maps.openGuide(name: name)
            let response = GuideResponse(opened: true, name: name)
            return HandlerUtilities.successResult(response)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - maps_nearby

    /// Finds nearby places by category.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: category (required), near (optional), limit (optional).
    /// - Returns: JSON array of nearby locations.
    ///
    /// Service errors are caught and returned as `CallTool.Result` with `isError: true`:
    /// - `ValidationError.missingRequired`: Category is empty.
    /// - `AppleScriptError.executionFailed`: AppleScript execution failed.
    /// - `AppleScriptError.timeout`: AppleScript execution timed out.
    static func nearbyLocations(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        guard let category = HandlerUtilities.extractString(from: arguments, key: "category") else {
            return HandlerUtilities.missingRequiredParameter("category")
        }

        // Additional validation for empty category
        if category.isEmpty {
            return HandlerUtilities.errorResult(ValidationError.missingRequired(field: "category"))
        }

        let near = HandlerUtilities.extractString(from: arguments, key: "near")
        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? 10

        do {
            let page = try await services.maps.nearby(category: category, near: near, limit: limit)
            return HandlerUtilities.successResult(page)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }
}
