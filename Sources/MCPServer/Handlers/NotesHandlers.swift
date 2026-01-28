import Foundation
import MCP
import Core

/// MCP tool handlers for Notes operations.
///
/// Provides handlers for the 4 Notes tools:
/// - `notes_search` - Search notes by query
/// - `notes_get` - Get a note by ID
/// - `notes_create` - Create a new note
/// - `notes_open` - Open a note in Notes app
///
/// ## Usage
/// These handlers are automatically registered in `ToolRegistry.create(services:)`.
/// Each handler follows the standard pattern of extracting arguments, calling the
/// service, and formatting the response.
enum NotesHandlers {

    /// Default limit for search results when not specified.
    private static let defaultLimit = 20

    // MARK: - Search

    /// Handles the `notes_search` tool.
    ///
    /// Searches notes by query string.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: MCP arguments containing `query` (required), `limit`, `includeBody`.
    /// - Returns: A `CallTool.Result` with paginated notes or an error.
    static func searchNotes(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        // Extract required query parameter
        guard let query = HandlerUtilities.extractString(from: arguments, key: "query") else {
            return HandlerUtilities.missingRequiredParameter("query")
        }

        // Extract optional parameters
        let limit = HandlerUtilities.extractInt(from: arguments, key: "limit") ?? defaultLimit
        let includeBody = HandlerUtilities.extractBool(from: arguments, key: "includeBody") ?? false

        do {
            let results = try await services.notes.search(
                query: query,
                limit: limit,
                includeBody: includeBody
            )
            return HandlerUtilities.successResult(results)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - Get

    /// Handles the `notes_get` tool.
    ///
    /// Retrieves a note by its ID.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: A `CallTool.Result` with the note or an error.
    static func getNote(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        // Extract required id parameter
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            let note = try await services.notes.get(id: id)
            return HandlerUtilities.successResult(note)
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - Create

    /// Handles the `notes_create` tool.
    ///
    /// Creates a new note.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: MCP arguments containing `title` (required), `body`, `folderId`.
    /// - Returns: A `CallTool.Result` with the new note ID or an error.
    static func createNote(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        // Extract required title parameter
        guard let title = HandlerUtilities.extractString(from: arguments, key: "title") else {
            return HandlerUtilities.missingRequiredParameter("title")
        }

        // Extract optional parameters
        let body = HandlerUtilities.extractString(from: arguments, key: "body")
        let folderId = HandlerUtilities.extractString(from: arguments, key: "folderId")

        do {
            let id = try await services.notes.create(
                title: title,
                body: body,
                folderId: folderId
            )

            // Return success response with created ID
            struct CreateResponse: Codable {
                let id: String
                let success: Bool
            }
            return HandlerUtilities.successResult(CreateResponse(id: id, success: true))
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }

    // MARK: - Open

    /// Handles the `notes_open` tool.
    ///
    /// Opens a note in the Notes app.
    ///
    /// - Parameters:
    ///   - services: The services container.
    ///   - arguments: MCP arguments containing `id` (required).
    /// - Returns: A `CallTool.Result` indicating success or error.
    static func openNote(
        services: any AppleServicesProtocol,
        arguments: [String: Value]?
    ) async -> CallTool.Result {
        // Extract required id parameter
        guard let id = HandlerUtilities.extractString(from: arguments, key: "id") else {
            return HandlerUtilities.missingRequiredParameter("id")
        }

        do {
            try await services.notes.open(id: id)

            // Return success response
            struct OpenResponse: Codable {
                let id: String
                let opened: Bool
            }
            return HandlerUtilities.successResult(OpenResponse(id: id, opened: true))
        } catch {
            return HandlerUtilities.errorResult(error)
        }
    }
}
