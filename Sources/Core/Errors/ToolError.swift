import Foundation

/// Error type for MCP tool-level failures.
public enum ToolError: Error, Sendable {
    case deadlineExceeded(seconds: Int)
    case cancelled
    case unknownTool(name: String)
    case internalError(message: String)

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
