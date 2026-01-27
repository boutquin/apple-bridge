import Foundation

/// Errors from MCP tool execution.
///
/// These errors occur at the MCP protocol level, independent of the underlying
/// Apple framework or database operations.
///
/// ## Error Categories
/// - `deadlineExceeded`: Operation took too long
/// - `cancelled`: Client cancelled the request
/// - `unknownTool`: Client requested a tool that doesn't exist
/// - `internalError`: Unexpected server-side error
///
/// ## Example
/// ```swift
/// do {
///     let result = try await server.callTool(name: "calendar.list")
/// } catch let error as ToolError {
///     print(error.userMessage)
/// }
/// ```
public enum ToolError: Error, Sendable {
    /// The operation exceeded its deadline.
    case deadlineExceeded(seconds: Int)

    /// The operation was cancelled by the client.
    case cancelled

    /// The requested tool name is not registered.
    case unknownTool(name: String)

    /// An unexpected internal error occurred.
    case internalError(message: String)

    /// A user-friendly message describing the error.
    public var userMessage: String {
        switch self {
        case .deadlineExceeded(let seconds):
            return "Tool deadline exceeded after \(seconds) seconds"
        case .cancelled:
            return "Tool operation was cancelled"
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}
