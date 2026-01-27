import Foundation
import MCP
import Core

/// Dispatches tool calls to the appropriate handlers with timeout protection.
///
/// The ToolDispatcher wraps the ToolRegistry to add timeout handling and
/// error normalization. It ensures that all tool calls complete within a
/// specified time limit.
///
/// ## Usage
/// ```swift
/// let registry = ToolRegistry.create(services: services)
/// let dispatcher = ToolDispatcher(registry: registry, timeout: .seconds(30))
/// let result = await dispatcher.dispatch(name: "calendar_list", arguments: nil)
/// ```
public actor ToolDispatcher {

    // MARK: - Properties

    /// The tool registry containing all tool definitions and handlers.
    private let registry: ToolRegistry

    /// The default timeout duration for tool calls.
    private let timeout: Duration

    // MARK: - Initialization

    /// Creates a new tool dispatcher.
    /// - Parameters:
    ///   - registry: The tool registry to dispatch calls to.
    ///   - timeout: The default timeout for tool calls. Defaults to 30 seconds.
    public init(registry: ToolRegistry, timeout: Duration = .seconds(30)) {
        self.registry = registry
        self.timeout = timeout
    }

    // MARK: - Public API

    /// Dispatches a tool call to the appropriate handler.
    ///
    /// The call is executed with timeout protection. If the handler exceeds
    /// the timeout, a timeout error result is returned.
    ///
    /// - Parameters:
    ///   - name: The name of the tool to call.
    ///   - arguments: The arguments to pass to the tool.
    /// - Returns: The tool call result.
    public func dispatch(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        do {
            return try await withTimeout(duration: timeout) { [registry] in
                await registry.callTool(name: name, arguments: arguments)
            }
        } catch let error as ToolError {
            return errorResult(for: error, toolName: name)
        } catch {
            return CallTool.Result(
                content: [.text("INTERNAL_ERROR: Unexpected error executing '\(name)': \(error)")],
                isError: true
            )
        }
    }

    /// Returns all tool definitions from the registry.
    public var definitions: [Tool] {
        get async {
            await registry.definitions
        }
    }

    // MARK: - Private Helpers

    /// Converts a ToolError to a CallTool.Result with appropriate error message.
    private func errorResult(for error: ToolError, toolName: String) -> CallTool.Result {
        let message: String
        switch error {
        case .deadlineExceeded(let seconds):
            message = "TIMEOUT: Tool '\(toolName)' timed out after \(seconds) seconds"
        case .cancelled:
            message = "CANCELLED: Tool '\(toolName)' was cancelled"
        case .unknownTool(let name):
            message = "UNKNOWN_TOOL: '\(name)' is not a registered tool"
        case .internalError(let msg):
            message = "INTERNAL_ERROR: Tool '\(toolName)' failed: \(msg)"
        }
        return CallTool.Result(content: [.text(message)], isError: true)
    }
}
